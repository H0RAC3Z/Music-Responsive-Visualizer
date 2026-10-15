# Music-Responsive Visualizer Project
This project was built using Processing in Java mode.   
It allows the user to input a MP3, WAV, or AIFF file and see 64 different frequency values. It also includes a microphone input mode.
## Features
- Use amplitude (loudness) → circle size, and bar height for the frequency history.
- Use frequency spectrum → radial distortion and bars.
- Microphone mode and file upload mode.
- History trail to show sound change over time.
## How to Run
1. Open `assignment1.pde` in the Processing IDE.
2. Click the **Run** button ( ).
3. Check the controls out, but the application launches in microphone mode.
## Controls
- `M`: Microphone mode
- `F`: File mode / initial file upload
- `O`: Open new file, generally for changing songs
- `Space`: Pause / play song loaded
## Example Output
### In Microphone Mode:   
![alt text](micMode.png)   
### In File Mode Playing (using the included audio test file):   
![alt text](filePlay.png)
### In File Mode Pausing (using the included audio test file):   
![alt text](filePause.png)
## Code Snippets
```Java
// ---------------------------------------------------------------------------
// Main animation loop
// ---------------------------------------------------------------------------
void draw() {
  // Clear each frame; the explicit history buffer below provides the trail.
  background(night);
  drawBackdrop(); // Draws initial backdrop
  analyzeActiveSource(); // Analysis of active input
  smoothAudioData(); // Smoothen audio

  orbPhase += 0.025 + smoothLevel * 0.045; // animation phase
  if (frameCount % 3 == 0) recordHistory(); // record into history every 3 frames
  drawCityline(); // small buildings as decoration
  drawOrb(); // Draw orb
  drawHistory();
  drawHeader();
  drawErrorToast();
}
```   
This is the main frame drawing loop.   
`background()` clears the previous frames,   
`drawBackdrop()` draws the initial backdrop/background of the app,   
`analyzeActiveSource()` makes sure we are drawing from the right input devices at the right times,   
`smoothAudioData` utilizes a lot of linear interpolation to ensure that audio changes are not rigid in animation,   
`orbPhase` changes the phase in the equation that is used in `drawOrb()`,   
`drawHeader` draws the labels and controls,   
`drawErrorToast` draws the error toast that is returned to the user if there is one.   

```Java
// ---------------------------------------------------------------------------
// Draws the orb using smoothness and math
// ---------------------------------------------------------------------------
void drawOrb() {
  // Keep the orb anchored in the center; only its outline responds to sound.
  float cx = width/2;
  float cy = 260;
  float baseRadius = 92 + smoothLevel * 30;

  // Soft halo follows loudness and the outline deforms to the live frequency bins.
  noStroke();
  fill(glow, 5 + smoothLevel * 12);
  ellipse(cx, cy, (baseRadius + 36) * 2, (baseRadius + 36) * 2);
  fill(violet, 8 + smoothLevel * 12);
  ellipse(cx, cy, baseRadius * 1.25, baseRadius * 1.25);

  noFill();
  stroke(violet, 85);
  strokeWeight(1);
  ellipse(cx, cy, (baseRadius + 22) * 2, (baseRadius + 22) * 2);
  stroke(glow, 45);
  ellipse(cx, cy, (baseRadius - 16) * 2, (baseRadius - 16) * 2);

  int points = 128;
  noFill();
  stroke(lerpColor(glow, violet, 0.24), 235);
  strokeWeight(2.8);
  beginShape();
  for (int p = -2; p < points + 3; p++) {
    int wrapped = (p + points) % points;
    float a = TWO_PI * wrapped / points;
    int band = (wrapped * BANDS) / points;
    float energy = smoothBand[band];
    float wave = sin(a * 5 + orbPhase) * smoothLevel * 6;
    float r = baseRadius + energy * 54 + wave;
    curveVertex(cx + cos(a) * r, cy + sin(a) * r);
  }
  endShape();

  // Small radial bars sit just beyond the orb's outline. Their individual
  // bands and the overall loudness both affect their length and brightness.
  for (int i = 0; i < BANDS; i++) {
    float a = TWO_PI * i / BANDS;
    float r1 = baseRadius + smoothBand[i] * 54 + 5;
    float barLength = 2 + smoothLevel * 10 + smoothBand[i] * 16;
    float r2 = r1 + barLength;
    float colorPosition = (float)i / BANDS;
    color c = colorPosition < 0.5
      ? lerpColor(glow, violet, colorPosition * 2)
      : lerpColor(violet, accent, (colorPosition - 0.5) * 2);
    stroke(c, 85 + smoothLevel * 85 + smoothBand[i] * 90);
    strokeWeight(2.2);
    line(cx + cos(a) * r1, cy + sin(a) * r1,
         cx + cos(a) * r2, cy + sin(a) * r2);
  }

  noStroke();
  fill(233, 243, 242, 190);
  ellipse(cx, cy, 4 + smoothLevel * 10, 4 + smoothLevel * 10);
}
```   
The above code draws the custom orb in the middle that distorts based on the 64 frequency values. we utilize linear interpolation a lot to introduce gradual change in color and animation.   

```Java
// ---------------------------------------------------------------------------
// Draws the frequency history animation using recorded history
// ---------------------------------------------------------------------------
void drawHistory() {
  float left = 58;
  float right = width - 58;
  float top = 440;
  float bottom = 588;
  float cellW = (right - left) / HISTORY_COLUMNS;

  noStroke();
  fill(ink, 235);
  textAlign(LEFT, BOTTOM);
  textSize(13);
  text("FREQUENCY HISTORY", left, top - 1);
  textAlign(RIGHT, BOTTOM);
  fill(accent);
  text("NOW", right, top - 1);

  // Each column is a snapshot: Bar height shows the strength of its spectrum.
  // Time runs left to right, with the newest sample at the right edge.
  for (int x = 0; x < HISTORY_COLUMNS; x++) {
    float strongest = 0;
    for (int b = 0; b < BANDS; b++) {
      float energy = history[x][b];
      if (energy > strongest) {
        strongest = energy;
      }
    }
    float barHeight = pow(strongest, 0.82) * (bottom - top) * 0.62;
    // Leave clear space under the FREQUENCY HISTORY label, even for loud peaks.
    barHeight = constrain(barHeight, 0, (bottom - top) - 18);
    if (barHeight < 1.5) continue;
    // The trail shifts from cool distant bars to pink at the newest edge.
    float colorPosition = (float)x / (HISTORY_COLUMNS - 1);
    color c = colorPosition < 0.58
      ? lerpColor(glow, violet, colorPosition / 0.58)
      : lerpColor(violet, accent, (colorPosition - 0.58) / 0.42);
    float xPos = left + x * cellW + 0.8;
    float barW = max(1, cellW - 1.6);
    fill(c, 34);
    rect(xPos - 1, bottom - barHeight - 3, barW + 2, barHeight + 3, 2);
    fill(c, x == HISTORY_COLUMNS - 1 ? 245 : 185);
    rect(xPos, bottom - barHeight, barW, barHeight, 2);
  }

  stroke(glow, 125);
  strokeWeight(2);
  line(right - cellW, top + 4, right - cellW, bottom);
  stroke(ink, 90);
  strokeWeight(1);
  line(left, bottom, right, bottom);
  noStroke();
}
```
Finds the strongest value in each of the 64 bands of frequency and draws that as the trailing history. We store 150 history columns for the user to see at one time. We also make sure the bars are constrained so that they don't mess up or block other UI elements. 

## Future Considerations
- Background noise suppression should be looked at because microphone keeps picking up white noise, making it harder to test the frequency values.   
- For visual appeal, look into how to make lights on the buildings gradually glow randomly without disturbing the main focal point.