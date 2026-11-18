const int buttonPins[] = {D2, D3};
const int greenLed = D8;
const int redLed = D9;
const char* messages[] = {"NORMAL", "MODIFIED"};

bool lastRead[] = {HIGH, HIGH};
bool stable[] = {HIGH, HIGH};
unsigned long changedAt[2];

void setup() {
  Serial.begin(115200);
  for (int pin : buttonPins) {
    pinMode(pin, INPUT_PULLUP);
  }
  pinMode(greenLed, OUTPUT);
  pinMode(redLed, OUTPUT);
}

void loop() {
  for (int i = 0; i < 2; ++i) {
    bool reading = digitalRead(buttonPins[i]);
    if (reading != lastRead[i]) {
      lastRead[i] = reading;
      changedAt[i] = millis();
    }
    if (reading != stable[i] && millis() - changedAt[i] >= 30) {
      stable[i] = reading;
      if (reading == LOW) {
        Serial.println(messages[i]);
      }
    }
  }

  while (Serial.available()) {
    int result = Serial.read();
    digitalWrite(greenLed, result == 'G' ? HIGH : LOW);
    digitalWrite(redLed, result == 'R' ? HIGH : LOW);
  }
}
