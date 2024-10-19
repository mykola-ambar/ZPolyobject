class PolyobjectDoorSoundBlockEffector: PolyobjectEffector
{
  // This effector keeps track of whether a polyobject door is open, and blocks sound
  // propagation accordingly.
  // If the polyobject is in its initial position, the door is considered closed and 
  // all the sector lines around the polyobject start spot are set to block sound.
  // Otherwise the door is considered open and the lines are set to not block sound.

  // Current door state
  bool IsOpen;

  // Sets or unsets all lines in a sector to block sound
  static void SectorSoundBlockingSet(Sector sector, bool blocksound)
  {
    // Go through every line in the sector
    for (int i = 0; i < sector.Lines.Size(); i++)
    {
      Line line = sector.Lines[i];
      
      if (blocksound)
      {
        // Sound is blocked, set the flag
        line.Flags |= Line.ML_SOUNDBLOCK;
      }
      else
      {
        // Sound is not blocked, unset the flag
        line.Flags &= ~Line.ML_SOUNDBLOCK;
      }
    }
  }

  override void OnAdd()
  {
    // Set the lines around the affected polyobjects to block sound
    SectorSoundBlockingSet(Polyobject.GetSector(), true);
  }

  override void PolyTick()
  {
    if (!Polyobject.IsAtOrigin() && !IsOpen)
    {
      // Door moved from its default position, unblock sound
      IsOpen = true;
      SectorSoundBlockingSet(Polyobject.GetSector(), false);
    }
    else if (Polyobject.IsAtOrigin() && IsOpen)
    {
      // Door moved to its default position, block sound
      IsOpen = false;
      SectorSoundBlockingSet(Polyobject.GetSector(), true);
    }
  }
}


class PolyobjectDoorSoundBlockEventHandler: EventHandler
{
  // This event handler applies PolyobjectDoorSoundBlockEffector to every polyobject
  // on the map.

  override void WorldLoaded(WorldEvent e)
  {
    // Don't apply effectors if the map has been visited before
    if (e.IsReopen)
      return;

    // Iterate through all polyobjects on the map
    let it = PolyobjectIterator.Create();
    PolyobjectHandle po;
    while ((po = it.Next()) != NULL)
    {
      // Create a new effector instance and add it to polyobject's effectors
      PolyobjectDoorSoundBlockEffector eff = New('PolyobjectDoorSoundBlockEffector');
      po.AddEffector(eff);
    }
  }
}
