
int size = 64;
int dtime = 30;

void setup() {
  // put your setup code here, to run once:

  pinMode(13, OUTPUT);
  pinMode(1, OUTPUT);

  digitalWrite(1, LOW);
  for (int i = 0; i < 128; i++) {
    delay(dtime);
    digitalWrite(13, HIGH); // Rising CLock edge
    delay(dtime);
    digitalWrite(13, LOW); // END CLOCK
  }
}


// 2 classroom per building schema

//                 New                             New                             New                             New
int stringA[64] = {1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
int stringB[64] = {1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,1,0,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
void loop() {

  for (int i = 0; i < size; i++) {
    // Add some delay:
    delay(dtime);
    digitalWrite(13, HIGH); // Rising CLock edge
    if (stringA[i] == 1) { // write high
      digitalWrite(1, HIGH);
    } else {
      digitalWrite(1, LOW);
    }
    delay(dtime);
    digitalWrite(13, LOW); // END CLOCK
  }

    for (int i = 0; i < size; i++) {
    // Add some delay:
    delay(dtime);
    digitalWrite(13, HIGH); // Rising CLock edge
    if (stringB[i] == 1) { // write high
      digitalWrite(1, HIGH);
    } else {
      digitalWrite(1, LOW);
    }
    delay(dtime);
    digitalWrite(13, LOW); // END CLOCK
  }
  // put your main code here, to run repeatedly:
//
//  digitalWrite(13, HIGH);
//  delay(1000);
//  digitalWrite(13, LOW);
//  delay(1000);


  
}
