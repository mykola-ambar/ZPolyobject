# ZPolyobject v1.0 - ZScript Polyobject library 
by Mikolah

This library adds Polyobject support to ZScript.

It makes querying polyobject state info, such as current position, velocity and 
rotation, possible from within ZScript.

In addition, it allows polyobject behavior to be
customized through polyobject effectors.

Originally I wrote this code a while back for Dynamo's WIP Wolf3D-based mod, but I 
think it might also be useful on its own as a standalone library.

The code is heavily commented, so don't hesitate to look at the sources if you need any help.

# Examples

## Including
```c++
#include "ZScript/Polyobjects/Polyobjects.zs"
```

## Querying basic info
```c++
/* ... */

// Print some info for polyobject 123
PolyobjectHandle po = PolyobjectHandle.FindPolyobj(123);
Console.Printf("Origin: %f %f", po.GetOrigin().x, po.GetOrigin().y);
Console.Printf("Current Position: %f %f", po.GetPos().x, po.GetPos().y); 
Console.Printf("Current Angle: %f", po.GetAngle());

/* ... */
```

## Iterating through polyobjects
```c++
/* ... */

PolyobjectIterator it = PolyobjectIterator.Create();
PolyobjectHandle po;
while ((po = it.Next()) != NULL)
{
    Console.Printf("Polyobject %i is rotated by %f degrees", po.PolyobjectNum, po.GetAngle());
}

/* ... */
```

## Effectors
### First, create an effector by inheriting from `PolyobjectEffector`:
```c++
class ExamplePolyobjectEffector: PolyobjectEffector
{
    // void OnAdd() is run immediately after the effector is added by PolyobjectHandle
    override void OnAdd()
    {
        // self.Polyobject holds a reference to the affected polyobject
        Console.Printf("Added by polyobject %i", Polyobject.PolyobjectNum);
    }

    // void PolyTick() is run every tic
    override void PolyTick()
    {
        // If too far away from initial position, return back
        if (Polyobject.GetPosDelta().Length() > 512)
        {
            Polyobject.MoveTo(NULL, Polyobject.GetOrigin(), 64);
            Console.Printf("there's no place like home");
        }
    }
}
```
### Then pass an effector instance to `PolyobjectHandler.AddEffector()` method:
```c++
/* ... */

let it = PolyobjectIterator.Create();
PolyobjectHandle po;
while ((po = it.Next()) != NULL)
{
    ExamplePolyobjectEffector poe = New('ExamplePolyobjectEffector');
    po.AddEffector(poe);
}

/* ... */
```

# Advanced examples
There are two examples in `/ZScript/Examples` directory inside the .pk3 file:

## Automatic sound blocking/unblocking
### `PolyobjectDoorSoundBlockEffector.zs`
This effector keeps track of whether a polyobject door is open or closed, and 
sets/unsets the "block sound" flag on linedefs of its surrounding sector accordingly.

## Wolfenstein-like door behavior 
### `PolyobjectWolfensteinDoorEffector.zs`
This effector gives polyobject door a more Wolf3D-like behavior:

1. The door will stay open if a player or a monster is in the way, and won't close until
there's nothing blocking it.
2. If the door has started closing, using it will immediately make it open again.

A small test map is included, go to `MAP01` to see both examples in action.

# Usage
Feel free to use this library in your projects, as long as you credit me.
Licensed under the MIT License.

# Credits
Dynamo, for helping me find and fix bugs
