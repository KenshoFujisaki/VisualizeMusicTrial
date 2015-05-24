// Ref: computer graphics - http://macromarionette.com/computergraphics/cg10.html
import ddf.minim.analysis.*;
import ddf.minim.*;

//キャンバス
int canvasW = displayWidth;
int canvasH = displayHeight;
int canvasFPS = 60;

//音声入力
int BUFSIZE = 1024;   //最大音量
Minim minim;
AudioInput in;
FFT fft;

// 回転角
float[] rot = new float[BUFSIZE];
float[] rotSpeed = new float[BUFSIZE];

/**
 * フルスクリーン
 **/
boolean sketchFullScreen() {
  return true;
}

/**
 * 初期化
 **/
void setup() {
  //キャンバス
  size(displayWidth, displayHeight);
  frameRate(canvasFPS);
  colorMode(HSB, 360, 100, 100, 100);
  smooth();  //アンチエイジング
  background(0);

  //音声入力
  minim = new Minim(this);
  in = minim.getLineIn(Minim.STEREO, BUFSIZE);
  fft = new FFT(in.bufferSize(), in.sampleRate());

  //回転角
  for (int i = 0; i < BUFSIZE; i++) {
    rot[i] = random(0, 360);
    rotSpeed[i] = 0;
  }
}

/**
 * 描画
 **/
void draw()
{
  backgroundFade();

  // 描画内容を画面中央に移動します
  translate(width/2, height/2);

  // FFT を実行します
  fft.forward(in.mix);
  float specSize = fft.specSize();  //周波数幅
  float getBand;
  for (int i = 0; i < specSize; i++) {
    pushMatrix();

    //音量 -> 回転角
    getBand = fft.getBand(i) * 2;
    rotSpeed[i] = getBand;
    rot[i] += rotSpeed[i] * 1.5;
    rotate(radians(rot[i]));

    //周波数 -> 色相
    float h = map(i, 0, specSize, 0, 255);
    float fillColor = h * 2.5;
    fill(fillColor, fillColor, fillColor);
    noStroke();

    //周波数，音量 -> 描画位置
    float x = map(i, 0, specSize, 0, height);
    float l = map(getBand, 0, BUFSIZE/16, 0, 50);
    float circleSize = min(l*l/5, 100);
    if (x>50) {
      ellipse(x, x, circleSize, circleSize);
      smooth();
    }

    popMatrix();
  }
}

/**
 * 背景の塗りつぶし
 **/
void backgroundFade()
{
  noStroke();
  fill(0, 50);
  rect(0, 0, width, height);
}

/**
 * 終了関数
 **/
void stop()
{
  minim.stop();
  super.stop();
}
