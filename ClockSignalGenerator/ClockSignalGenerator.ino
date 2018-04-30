int dtime = 20;
// Theo Stanebye
// this file intends to generate a clock signal for use in our DLD group project.
// The clock signal is emmited on pin 13 and goes high and low once per void loop.
void setup() {
  // put your setup code here, to run once:
  pinMode(13, OUTPUT);
}

void loop() {
  delay(dtime);
  digitalWrite(13, HIGH); // Rising CLock edge
  delay(dtime);
  digitalWrite(13, LOW);
}
