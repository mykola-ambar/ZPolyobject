class PolyobjectWolfensteinDoorEffector: PolyobjectEffector
{
  // This effector makes a polyobject behave like a Wolf3D door.
  // The behavior is similar to the Polyobj_DoorSlide action special, slightly changed.
  // Trying to open the door while it's closing will cause it to start re-opening.
  // The door won't close if a player or a monster (either dead or alive)
  // is blocking its way, and will stay open until the blocking moves aside.

  // Actor activating the door
  Actor Activator;

  // Tics to wait before closing the door
  int Delay;

  // Door speed
  int Speed;

  // Open door position
  Vector2 Destination;

  // Tics remaining before the door closes
  int Counter;

  // Center coordinates of the sector containing the polyobject
  Vector3 CenterSpot;

  // Radius around CenterSpot in which actors can block the door
  double BlockRadius;

  // Actor blocking the door from closing
  Actor Blocker;

  // Possible door statuses
  enum WolfDoorStatus
  {
    WDST_CLOSED,   // Fully closed
    WDST_OPENING,  // Moving towards destination
    WDST_OPEN,     // Fully open
    WDST_CLOSING,  // Moving towards initial position
  }

  // Current door status
  WolfDoorStatus Status;

  // Open the door
  void Open()
  {
    // Door is opening, set status accordingly
    Status = WDST_OPENING;

    // Reset the countdown 
    Counter = Delay;

    // Move the polyobject to destination
    Polyobject.MoveTo(Activator, Destination, Speed, 0);  // SNDSEQ sound 0 for opening
  }

  // Try to open the door, if possible
  bool TryOpen()
  {
    // An open door can't be opened
    if (Status == WDST_OPENING || Status == WDST_OPEN)
      return false;

    // Open the door
    Open();
    return true;
  }

  // Check if a given actor prevents the door from closing
  bool IsActorBlocking(Actor a)
  {
    // Doors are blocked by players and monsters (including corpses) if they are close
    // enough to CenterSpot
    return (a.bIsMonster || a.Player) 
            && (BlockRadius + a.Radius > (CenterSpot.xy - a.Pos.xy).Length());
  }

  // Find an actor that prevents the door from closing, if one exists
  Actor FindBlockingActor()
  {
    // Iterate over actors that are close to the door
    BlockThingsIterator it = BlockThingsIterator.CreateFromPos(
      CenterSpot.x, CenterSpot.y, CenterSpot.z, 
      512, (Polyobject.StartSpotPos - destination).Length(), false);
    while (it.Next())
    {
      if (IsActorBlocking(it.Thing))
      {
        return it.thing;
      }
    }
    return NULL;
  }


  // Try to close the door, if possible
  bool TryClose()
  {
    // Check if still blocked by the same actor
    if (Blocker != NULL)
    {
      if (IsActorBlocking(Blocker))
      {
        return false;
      }
    }

    // Check if any actors are blocking the door
    Blocker = FindBlockingActor();
    if (Blocker)
    {
      // The door is blocked, don't close
      return false;
    }

    // Close the door
    Close();
    return true;
  }

  // Close the door
  void Close()
  {
    // Door is closing, set status accordingly
    Status = WDST_CLOSING;
    Polyobject.MoveTo(Activator, Polyobject.StartSpotPos, Speed, 1); // SNDSEQ sound 1 for closing
  }

  override void OnAdd()
  {
    // We assume that the door is contained within a sector that more-or-less matches
    // the door shape, and its center is close enough to the middle of the door.
    CenterSpot = (Polyobject.GetSector().CenterSpot, Polyobject.GetSector().FloorPlane.ZAtPoint(Polyobject.GetSector().CenterSpot));

    // We assume that the travel distance of the door is about the same as its width, 
    // and any actor within a half-width radius is close enough to block the door.
    BlockRadius = (Polyobject.StartSpotPos - Destination).Length() / 2.0;
  }

  override void PolyTick()
  {
    // Track polyobject position and update door status accordingly

    if (!Polyobject.IsMoving())
    {
      if (Polyobject.GetPos() == Destination)
      {
        // Polyobject reached its destination and stopped moving, the door is fully open
        Status = WDST_OPEN;
      }
      else if (Status == WDST_CLOSING)
      {
        if (Polyobject.IsAtOrigin())
        {
          // Polyobject reached its origin and stopped moving, the door is fully closed
          Status = WDST_CLOSED;
        }
        else
        {
          // The door has stopped midway while closing, something is blocking it.
          // Reopen the door
          Open();
        }
      }
    }

    if (Status == WDST_OPEN)
    {
      // Decrement tics remaining until the door closes
      Counter--;
      if (Counter <= 0)
      {
        // No more tics remaining, close the door if possible
        Counter = 0;
        TryClose();
      }
    }
    else if (Status == WDST_CLOSED)
    {
      // The door is fully closed, destroy the effector
      Destroy();
    }
  }
}

class WolfensteinDoorEventHandler: EventHandler
{

  // This event handler adds Wolf3D-like behavior to sliding polyobject doors by
  // intercepting linedef activations of Polyobj_SlideDoor action special and 
  // using PolyobjectWolfensteinDoorEffector instead
  override void WorldLinePreActivated(WorldEvent e)
  {
    Line line = e.ActivatedLine;

    // Ignore all other specials
    if (line.Special != Polyobj_DoorSlide)
      return;

    // Get the handle to the affected polyobject 
    int pobjnum = line.Args[0];
    PolyobjectHandle po = PolyobjectHandle.FindPolyobj(pobjnum);
    if (po == NULL)
      return;

    // Prevent Polyobj_DoorSlide from activating
    e.ShouldActivate = false;

    // Movement speed
    int speed = line.Args[1];

    // Movement angle
    int byteangle = line.Args[2];
    double angle = byteangle * 360.0 / 256.0;

    // Movement distance
    int distance = line.Args[3];

    // Delay before closing
    int delay = line.Args[4];

    // Movement destination
    Vector2 destination = Actor.AngleToVector(angle, distance) + po.StartSpotPos;

    // Line special activator
    Actor activator = e.Thing;

    // Temporarily unset line special to prevent infinite recursion
    line.Special = -1;

    // Check if activator is actually able activate the line
    if (line.Activate(activator, Line.front, e.ActivationType))
    {
      // Check if the polyobject has this effector already
      // (for cases like trying to open the door while it's closing)
      PolyobjectWolfensteinDoorEffector eff = PolyobjectWolfensteinDoorEffector(po.FindEffector('PolyobjectWolfensteinDoorEffector'));

      if (eff == NULL)
      {
        // Create an effector instance from scratch
        eff = PolyobjectWolfensteinDoorEffector(New('PolyobjectWolfensteinDoorEffector'));

        eff.Activator = activator;
        eff.Destination = destination;
        eff.Delay = delay;
        eff.Speed = speed;

        // Add effector to the polyobject
        po.AddEffector(eff);
      }

      // Open the door if possible
      eff.TryOpen();
    }
    // Reset line special to Polyobj_DoorSlide
    line.Special = Polyobj_DoorSlide;
  }
}
