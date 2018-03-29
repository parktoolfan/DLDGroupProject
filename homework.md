# DLD Group Project

#### Theo Stangebye - March 28, 2018
#### Group Members: Nate, Daniel, Theo, and Armand

## Project Info

Our goal is to design a system that accomplished 3 items for each "classroom" or compatible study area on campus (called classrooms from here out). Each classroom has 3 bits of output and 2 bits of input.  The three bits of output represent the following values: `LightsAreOn`, `ProjectorIsOn`, and `ClassroomInUse`.  The classroom's two inputs are `projectorEnable` and `lightsEnable`.  Each of these signals is **Active High**

Our system needs to:
 
1. Enable the lights and projector in a classroom immediately when someone enters and begins using the classroom (set `projectorEnable` and `lightsEnable` to High).
2. Set the output bits of that classroom to represent that classroom's state (is the projector being used? - then set `ProjectorIsOn` to High).
3. Collect the 3 bits of output from each classroom on campus and write it into some form of data stream (which could later be used for some app, webservice, etc). 

- There are 8 buildings on campus that we would like to bring online for this sysem. - We'll decide which ones these are later.
- Each building can have up to 64 classrooms, each with its own `classroomController`.
- Each building has a `buildingController` that collects information on the state of the classroom and can issue commands to that classroom's `classroomController`.
- There is a `campusController` that reads information from each of the `buildingController`s and can set commands for each classroom.

### classroomController

The `classroomController` has 2 input bits, 3 output bits, and 4 `transmit` bits.
The `transmit` bits are set by the `buildingController`.  each `classroomController` has a 4 bit binary integer assigned to it


## Easter Break Goals



