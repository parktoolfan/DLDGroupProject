# DLD Group Project

#### Theo Stangebye - March 28, 2018
#### Group Members: Nate, Daniel, Theo, and Armand

**Easter Break Goals at bottom**.

## Project Info

Our goal is to design a system that accomplished 3 items for each "classroom" or compatible study area on campus (called classrooms from here out). Each classroom has 1 bit of output and 1 bit of input. Each of these signals is **Active High**.  The input and output bits of each classroom transmits the following values: `LightsAreOn`, `ProjectorIsOn`, `ClassroomInUse`, `projectorEnable` and `lightsEnable`.  The first three values are outputs from the classroom and the last two are inputs to the classroom for control purposes. Each classroom has a `classroomController` and all of these are connected by a `buildingController`.  Finally, a `campusController` monitors all of the `buildingControllers`.

Our system needs to:

1. Enable the lights and projector in a classroom immediately when someone enters and begins using the classroom (set `projectorEnable` and `lightsEnable` to High).
2. Set the output bits of that classroom to represent that classroom's state (is the projector being used? - then set `ProjectorIsOn` to High).
3. Collect the 3 bits of output from each classroom on campus and write it into some form of data stream (which could later be used for some app, webservice, etc) and control the classroom's lights and projector based on that `classroomController`'s inputs from the `buildingController`.

- There are 8 buildings on campus that we would like to bring online for this sysem. - We'll decide which ones these are later.
- Each building can have up to 64 classrooms, each with its own `classroomController`.
- Each building has a `buildingController` that collects information on the state of the classroom and can issue commands to that classroom's `classroomController` to enable or disable the classroom's lights and projector.
- There is a `campusController` that reads information from each of the `buildingController`s and can set commands for each classroom.

### classroomController

Each `classroomController` has 3 sensors: `LightsAreOn`, `ProjectorIsOn` and `ClassroomInUse` and two things that it controls: `projectorEnable` and `lightsEnable`.  The controller also has a TX bit, an RX bit, and 6 `roomID` bits to communicate with the rest of the building. Think of the `roomID` bits as select bits that allow the `buildingController` to select which classroom it is talking to. There is also a `clock` input on each `classroomController`.

The `classroomController` a 6 bit binary number associated with it, these 6 bits are the controllers `roomID`.  The `classroomController` should do the following:

1. If someone begins using the classroom - or if `ClassroomInUse` = 1, the controller should make sure that `projectorEnable` and `lightsEnable` are active and remain so until the classroom is no longer in use.
2. Read from the classroom's sensors (`LightsAreOn`, `ProjectorIsOn` and `ClassroomInUse`) and store their values into memory.
3. When the classroom's controller is selected by a `buildingController` (meaning that the `buildingController` has broadcasted this specific `classroomController`'s unique 6 bit number on the `roomID` bits), the `classroomController` should use its `RX` and `TX` bits to transmit it's sensor data and read commands from teh `buildingController`.  We will use a FSM to recodnize sequential bit strings on the `RX` and `TX` pins to communicate.

**For this week,** lets focus on getting the classroomController to bring it's `TX` and `RX` bits online using tristate buffers when it's unique id is selected by a `buldingController`.  Have the `classroomController` tranmit a "11010101" on its `TX` bit after it is selected and store the bitstream from its `RX` bit into an 8 bit bitstring.

### buildingController

The bulding controller should increment through all the classrooms for a building, staying on each classroom for 8 clock cycles.  For instance, starting at the first classroom in the building, it should transmit '000000' to all of the `classroomController`s in the building using its `roomSelect` output (this is 6 bits that are wirred to the `roomID` selector on the `classroomControllers`), wait one clock cycle, and then tranmit a "00100010" on its `TX` bit and store the 8 bits from its `RX` pin to an 8 bit bitstring before incrementing `roomSelect` to '000001' and repeating for the second classroom.  **The `buildingController` also provides the clock signal that is used by all of the `classroomController`s.**

**For this week** let's focus on getting the main functionality of the `buildingController` implemented and we can focus on interfacing with the `campusController` and storing all 64 classroom's worth of information later.  For now, just store the bitstream from each classroom into one 8 bit number and overwrite that number for every classroom.

> A bitstring is a concurrent number of bits (think a number of wires in parallel) while a bit**stream** is a sequential series of sequential bits sent across 1 wire.

## Easter Break Goals

- Armand - can you design the `classroomController`
- Nate and Dan - because you guys are together, can you brainstorm an 8 bit bitstrem for the setting a classroom's lights and projector and an 8 bit bitstream to read from the classroom's sensors, and design the logic for the `buldingController`.
- I'll work on the `campusController` and come up with a scheme to store all of the informmation in each `buildingController` and at the `campusController` level.

###### Telegram me if you have questions.

