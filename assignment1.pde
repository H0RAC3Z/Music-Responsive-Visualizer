import processing.sound.*;

/*
  MUSIC-RESPONSIVE VISUALIZER

  Controls: M = microphone, 
            F = resume/switch to loaded file (will prompt for file if none), 
            O = open or replace file,
            SPACE = pause/resume the selected audio file
  Requires Processing's built-in Sound library (Sketch > Import Library > Sound).
*/

// Noise suppression may be a good feature to add later on.

// Audio sources and their dedicated analyzers. Keeping analyzers separate
// makes switching between the microphone and file playback more reliable.
AudioIn microphone;
SoundFile audioFile;
Amplitude micLoudness;
FFT micSpectrum; // FFT is Fast Fourier Transform. Essentially, it takes audio signal and breaks it into frequency bands.
Amplitude fileLoudness;
FFT fileSpectrum;

// Spectrum smoothing (gradual change of of values) and horizontal history, with the newest sample on the right.
final int BANDS = 64; // 64 frequency bands, mapped around the orb
final int HISTORY_COLUMNS = 150; // 150 frequency snapshots (each column displays the highest value frequency)
float[] fft = new float[BANDS]; // Holds the frequency bands
float[] smoothBand = new float[BANDS]; // Used to hold linear interpolation points between old and new frequency values
float[][] history = new float[HISTORY_COLUMNS][BANDS]; // Holds the current history of frequencies
float level = 0; // Audio loudness
float smoothLevel = 0; // Linear interpolation
float orbPhase = 0; // Animation phase
boolean fileMode = false; // Variable to track whether file mode is on or not
boolean filePaused = false; // Tracks paused file or not
boolean pausedByUser = false; // Yes if paused, no if pause is caused by switching modes
String currentFile = ""; // Stores current file name
String errorMessage = ""; // Stores the error message for meaningful user output
int errorExpiresAt = 0; // Times the error

// Color Scheme
// Midnight blue with electric cyan, violet, and neon-pink highlights.
color ink = #EAF0FF;
color glow = #42DFFF;
color accent = #FF4F9A;
color violet = #8B6CFF;
color night = #090D20;
color skyline = #101831;
color skylineAlt = #121D38;

// Fixed skyline layout; buildings flank the orb and stay below its contrast.
final int[] BUILDING_X = {38, 78, 122, 169, 212, 654, 696, 739, 783, 828};
final int[] BUILDING_W = {28, 35, 31, 39, 34, 34, 39, 32, 36, 30};
final int[] BUILDING_H = {90, 145, 115, 180, 132, 155, 205, 125, 175, 105};

// ---------------------------------------------------------------------------
// Setup involving initial settings and microphone mode
// ---------------------------------------------------------------------------
void setup() {
  // Use Processing's default renderer; this sketch does not need OpenGL/P2D.
  // Avoids requiring JOGL native libraries on systems where they are unavailable.
  size(900, 650);
  smooth(8); // 8 sample smoothing level for anti-aliasing
  frameRate(60); // sets limit of frame rate to 60

  microphone = new AudioIn(this, 0); // create microphone input for this sketch with audio input device 0 (Default)
  fileMode = false; // Always launch with live microphone input selected.
  filePaused = false;
  initializeMicrophone(); // init mic mode

  textFont(createFont("SansSerif", 13)); // set font and font size
}

// ---------------------------------------------------------------------------
// Initialize Microphone input with spectrum and loudness analysis
// ---------------------------------------------------------------------------
void initializeMicrophone() {
  microphone.start();
  micLoudness = new Amplitude(this);
  micLoudness.input(microphone);
  micSpectrum = new FFT(this, BANDS);
  micSpectrum.input(microphone);
}

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
  drawOrb(); // 
  drawHistory();
  drawHeader();
  drawErrorToast();
}

// ---------------------------------------------------------------------------
// Read from the active source
// ---------------------------------------------------------------------------
void analyzeActiveSource() {
  // Keep analyzers attached to their own sources and read only the active pair.
  if (fileMode && audioFile != null) {
    level = fileLoudness.analyze();
    fileSpectrum.analyze(fft);
  } else {
    level = micLoudness.analyze();
    micSpectrum.analyze(fft);
  }
}

// ---------------------------------------------------------------------------
// Apply smoothing and scaling of audio data
// ---------------------------------------------------------------------------
void smoothAudioData() {
  float targetLevel = constrain(level * 4.5, 0, 1);
  if (targetLevel < 0.025) targetLevel = 0;  // Ignore tiny input noise at idle.
  smoothLevel = lerp(smoothLevel, targetLevel, 0.18);
  for (int i = 0; i < BANDS; i++) {
    // Keep strong music from clipping every FFT bin to the same full scale.
    float targetBand = constrain(fft[i] * 3.2, 0, 1);
    if (targetBand < 0.035) targetBand = 0;
    // Rise quickly on a beat, then decay more slowly so the shape lingers.
    float bandResponse = targetBand > smoothBand[i] ? 0.30 : 0.10;
    smoothBand[i] = lerp(smoothBand[i], targetBand, bandResponse);
  }
}

// ---------------------------------------------------------------------------
// Visuals: frequency-reactive orb and scrolling bar history
// ---------------------------------------------------------------------------
void drawBackdrop() {
  // Fine interface grid and edge marks set a quiet night-city dashboard tone.
  stroke(66, 95, 150, 18);
  strokeWeight(1);
  for (int y = 96; y < height - 48; y += 48) line(28, y, width - 28, y);
  for (int x = 58; x < width - 40; x += 80) line(x, 96, x, height - 48);

  noFill();
  stroke(66, 223, 255, 80);
  rect(12, 12, width - 24, height - 24, 8);
  line(28, 61, 118, 61);
  line(width - 118, 72, width - 28, 72);
  noStroke();
}

// ---------------------------------------------------------------------------
// Draws dim buildings on either side of the orb.
// ---------------------------------------------------------------------------
void drawCityline() {
  // Taller, low-contrast buildings frame the orb without competing with it.
  int groundY = 420;
  for (int b = 0; b < BUILDING_X.length; b++) {
    int x = BUILDING_X[b];
    int top = groundY - BUILDING_H[b];
    fill((b % 2 == 0) ? color(skyline, 185) : color(skylineAlt, 170));
    rect(x, top, BUILDING_W[b], BUILDING_H[b]);
    // Sparse dim windows suggest a city at night while keeping the orb focal.
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 2; col++) {
        if ((row + col + b) % 3 == 0) continue;
        fill((row + b) % 2 == 0 ? color(glow, 65) : color(violet, 70));
        rect(x + 6 + col * 13, top + 9 + row * 12, 4, 5);
      }
    }
  }

  stroke(66, 223, 255, 32);
  strokeWeight(1);
  line(28, groundY, width - 28, groundY);
  noStroke();
}

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

// ---------------------------------------------------------------------------
// Saves current smoothed spectrum into history buffer/array
// ---------------------------------------------------------------------------
void recordHistory() {
  // Rotate row references instead of copying every value in the history matrix.
  float[] oldestColumn = history[0];
  for (int x = 0; x < HISTORY_COLUMNS - 1; x++) {
    history[x] = history[x + 1];
  }
  history[HISTORY_COLUMNS - 1] = oldestColumn; // reuse old column
  arrayCopy(smoothBand, oldestColumn); // replace old column with new values
}

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

// ---------------------------------------------------------------------------
// Labels and controls
// ---------------------------------------------------------------------------
void drawHeader() {
  fill(233, 243, 242, 235);
  textAlign(LEFT, TOP);
  textSize(18);
  text("MUSIC RESPONSIVE VISUALIZER", 28, 22);

  textSize(15);
  textAlign(LEFT, CENTER);
  String sourceLabel = fileMode ? "FILE  /  " + currentFile : "MICROPHONE";
  // Keep the badge clear of the title by shortening long displayed filenames.
  float maxLabelWidth = width - 28 - 42 - width * 0.42;
  while (textWidth(sourceLabel) > maxLabelWidth && sourceLabel.length() > 12) {
    sourceLabel = sourceLabel.substring(0, sourceLabel.length() - 4) + "...";
  }
  float labelWidth = textWidth(sourceLabel);
  float badgeX = width - 28 - labelWidth - 42;
  float badgeY = 17;
  float badgeW = labelWidth + 42;
  float badgeH = 31;
  color modeColor = fileMode ? accent : glow;
  noStroke();
  fill(modeColor, 24);
  rect(badgeX, badgeY, badgeW, badgeH, 15);
  noFill();
  stroke(modeColor, 145);
  strokeWeight(1);
  rect(badgeX, badgeY, badgeW, badgeH, 15);
  noStroke();
  fill(modeColor);
  ellipse(badgeX + 14, badgeY + badgeH/2, 8, 8);
  fill(ink);
  text(sourceLabel, badgeX + 25, badgeY + badgeH/2);

  // The bottom status pill uses an icon instead of a text message.
  float statusX = 68;
  float statusY = height - 47;
  float statusW = width - 136;
  noStroke();
  fill(16, 24, 48, 245);
  rect(statusX, statusY, statusW, 29, 14);
  noFill();
  color statusColor = !fileMode ? glow : (filePaused ? accent : violet);
  stroke(statusColor, 190);
  strokeWeight(1);
  rect(statusX, statusY, statusW, 29, 14);
  drawStatusIcon(width/2, statusY + 14.5, statusColor);

  drawControlPanel();
}

// ---------------------------------------------------------------------------
// Brief error message that appears on the screen, then disappears after a little
// ---------------------------------------------------------------------------
void drawErrorToast() {
  if (errorMessage.length() == 0 || millis() > errorExpiresAt) return;

  float toastW = 460;
  float toastH = 72;
  float toastX = (width - toastW) / 2;
  float toastY = 76;

  // toast background and outline
  noStroke();
  fill(28, 14, 38, 248);
  rect(toastX, toastY, toastW, toastH, 8);
  noFill();
  stroke(accent, 220);
  strokeWeight(1.5);
  rect(toastX, toastY, toastW, toastH, 8);

  // error message display
  textAlign(LEFT, TOP);
  textSize(11);
  fill(accent);
  text("AUDIO FILE ERROR", toastX + 14, toastY + 9);
  textSize(12);
  fill(ink);
  text(errorMessage, toastX + 14, toastY + 29, toastW - 28, toastH - 36);
}

// Explanation displayed in the error toast and console.
void showUserError(String message) {
  errorMessage = message;
  errorExpiresAt = millis() + 9000;
  println(message);
}

// cx, cy: Center point where the status symbol is drawn.
// iconColor: Tint matching the currently active input/playback state.
void drawStatusIcon(float cx, float cy, color iconColor) {
  stroke(iconColor);
  strokeWeight(2.2);
  strokeCap(ROUND);
  strokeJoin(ROUND);
  noFill();

  if (!fileMode) {
    // Microphone capsule, pickup arc, stem, and base.
    rect(cx - 4, cy - 10, 8, 14, 4);
    arc(cx, cy - 1, 18, 18, 0, PI);
    line(cx, cy + 8, cx, cy + 12);
    line(cx - 5, cy + 12, cx + 5, cy + 12);
  } else if (filePaused) {
    // Two pause bars.
    line(cx - 3, cy - 7, cx - 3, cy + 7);
    line(cx + 3, cy - 7, cx + 3, cy + 7);
  } else {
    // Play triangle.
    beginShape();
    vertex(cx - 4, cy - 8);
    vertex(cx + 7, cy);
    vertex(cx - 4, cy + 8);
    endShape(CLOSE);
  }
  strokeWeight(1);
  strokeCap(ROUND);
  strokeJoin(MITER);
}

void drawControlPanel() {
  float panelX = width - 222;
  float panelY = 58;
  float panelW = 190;
  float panelH = 112;

  noStroke();
  fill(14, 22, 45, 230);
  rect(panelX, panelY, panelW, panelH, 6);
  noFill();
  stroke(66, 223, 255, 85);
  strokeWeight(1);
  rect(panelX, panelY, panelW, panelH, 6);

  textAlign(LEFT, TOP);
  textSize(11);
  fill(glow);
  text("CONTROLS", panelX + 12, panelY + 10);

  textSize(11);
  String[] keys = {"[ M ]", "[ F ]", "[ O ]", "[ SPACE ]"};
  String[] actions = {"Microphone", "File / first load", "Open new file", "Play / pause"};
  for (int i = 0; i < keys.length; i++) {
    float rowY = panelY + 31 + i * 18;
    fill(accent);
    text(keys[i], panelX + 12, rowY);
    fill(ink, 220);
    text(actions[i], panelX + 76, rowY);
  }
}

// controls the controls
void keyPressed() {
  if (key == 'm' || key == 'M') useMicrophone();
  if (key == 'f' || key == 'F') {
    // F acts only from microphone mode; it never resumes a file from file mode.
    if (!fileMode) {
      if (audioFile == null) selectInput("Choose an audio file", "audioFileSelected");
      else useAudioFile();
    }
  }
  if (key == 'o' || key == 'O') selectInput("Choose an audio file", "audioFileSelected");
  if (key == ' ') toggleFilePlayback();
}

// ---------------------------------------------------------------------------
// Source switching and audio-file playback
// ---------------------------------------------------------------------------
void useMicrophone() {
  // Pause rather than stop so file mode can resume at the same position later.
  if (audioFile != null && fileMode) {
    audioFile.pause();
    filePaused = true;
  }
  fileMode = false;
  // Leave AudioIn running; switching only selects which analyzer is displayed.
}

void useAudioFile() {
  if (audioFile == null) {
    showUserError("No audio file is loaded. Press O to choose an MP3, WAV, or AIFF file.");
    return;
  }
  fileMode = true;
  if (filePaused && !pausedByUser) {
    audioFile.play();
    filePaused = false;
  }
}

// selection: File returned by Processing's chooser, and null means the user canceled it.
void audioFileSelected(File selection) {
  if (selection == null) return;

  String fileName = selection.getName();
  int dot = fileName.lastIndexOf('.');
  String extension = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : "";

  // The Sound library documents MP3, WAV, and AIFF. Reject other formats with
  // a useful conversion hint instead of letting the decoder fail silently.
  if (!extension.equals("mp3") && !extension.equals("wav") &&
      !extension.equals("aif") && !extension.equals("aiff")) {
    showUserError("Unsupported file type (." + extension + "). Choose MP3, WAV, or AIFF.");
    return;
  }

  try {
    // Prepare and start the candidate before changing the active source. If
    // decoding fails, the current microphone/file source keeps matching the UI.
    SoundFile candidate = new SoundFile(this, selection.getAbsolutePath());
    Amplitude candidateLoudness = new Amplitude(this);
    candidateLoudness.input(candidate);
    FFT candidateSpectrum = new FFT(this, BANDS);
    candidateSpectrum.input(candidate);
    candidate.play();

    if (audioFile != null) audioFile.stop();
    audioFile = candidate;
    fileLoudness = candidateLoudness;
    fileSpectrum = candidateSpectrum;
    currentFile = fileName;
    fileMode = true;
    filePaused = false;
    pausedByUser = false;
    errorMessage = "";
  } catch (Exception e) { // fail safe here
    // Keep the previous source and playback state intact on load failure.
    showUserError("Couldn't decode " + fileName + ". It may not be a real MP3 despite its extension. Convert it to MP3, WAV, or AIFF.");
    println("Audio file load failed: " + e.getMessage());
  }
}

// pause and unpausing
void toggleFilePlayback() {
  if (!fileMode || audioFile == null) return;
  if (filePaused) {
    audioFile.play();
    filePaused = false;
    pausedByUser = false;
  } else {
    audioFile.pause();
    filePaused = true;
    pausedByUser = true;
  }
}
