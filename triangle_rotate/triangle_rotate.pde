// output: Visualize music with processing - omega dubstep - YouTube - https://www.youtube.com/watch?v=aI5FN2hBX3M

import ddf.minim.*;
import ddf.minim.effects.*;
import ddf.minim.analysis.*;

//キャンバス
int canvasW = 1280;
int canvasH = 800;
int canvasFPS = 30;
boolean isFullscreen = true;

//音声入力
String audioFilepath = "audiofile.mp3";
int BUFSIZE = 2048;
Minim minim;
AudioPlayer player;

//FFT
FFT fft;

// 回転角
float[] rot = new float[BUFSIZE];
float[] rotSpeed = new float[BUFSIZE];
float speedCoef = 1.0;
float sizeCoef = 10;
float colorCoef = 3.0;

//フィルタ
LowPassSP lpf;
HighPassSP hpf;

/**
 * 正三角形
 * ref: http://noriok.hatenablog.com/entry/2012/09/17/173655
 **/
class EqTriangle { // equilateral triangle
    float x, y, n;
    public EqTriangle(int x, int y, int n) {
        this.x = x;
        this.y = y;
        this.n = n;
    }
    public void draw(int angle) {
        float b = this.n * sqrt(3) / 4.0;
        float c = this.n / 4.0;
        float d = c * tan(radians(30));

        float x1 = 0;
        float y1 = -(b + d);

        float r = radians(120);
        float x2 = x1*cos(r) - y1*sin(r);
        float y2 = x1*sin(r) + y1*cos(r);

        float x3 = x1*cos(r*2) - y1*sin(r*2);
        float y3 = x1*sin(r*2) + y1*cos(r*2);

        pushMatrix();
        translate(this.x, this.y);
        rotate(radians(angle));
        triangle(x1, y1, x2, y2, x3, y3);
        popMatrix();
    }
}

/**
 * 初期化
 **/
void setup()
{
  //キャンバス
  size(canvasW, canvasH);
  frameRate(canvasFPS);
  colorMode(HSB, 360, 100, 100, 100);
  //smooth();  //アンチエイジング
  background(0);

  //音声再生
  minim = new Minim(this);
  player = minim.loadFile(audioFilepath, BUFSIZE);
  player.loop();

  //FFT
  fft = new FFT(player.bufferSize(), player.sampleRate());

  //エフェクト
  lpf = new LowPassSP(5000, player.sampleRate());
  player.addEffect(lpf);
  hpf = new HighPassSP(100, player.sampleRate());
  player.addEffect(hpf);

  //回転角
  for (int i = 0; i < BUFSIZE; i++) {
    rot[i] = random(0, 360);
    rotSpeed[i] = 0;
  }
}

/**
 * 描画
 **/
void draw(){
  backgroundFade();
  translate(width/2, height/2);

  // FFT
  fft.forward(player.mix);
  float specSize = fft.specSize();  //周波数幅
  float getBand;
  for (int i = 0; i < specSize; i++) {
    pushMatrix();

    //音量 -> 回転角
    getBand = fft.getBand(i);
    rotSpeed[i] = getBand;
    rot[i] += rotSpeed[i];
    rotate(radians(rot[i]) * speedCoef);

    //周波数 -> 色相
    float h = map(i, 0, specSize, 0, 255);
    float fillColor = h * colorCoef;
    fill(fillColor, fillColor, fillColor, 80);
    noStroke();

    //周波数，音量 -> 描画位置
    float x = map(i, 0, specSize, 0, height) + getBand * 2;
    float l = map(getBand, 0, BUFSIZE/16, 0, 50);
    //float circleSize = min(log(l) * sizeCoef, 100);
    float circleSize = l * sizeCoef;
    if (x>5) {
      EqTriangle t = new EqTriangle((int)x, (int)x, (int)circleSize);
      t.draw(0);
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
 * LPF/HPFエフェクト
 **/
void mouseMoved()
{
  //LPF
  float cutoff = map(mouseX, 0, canvasW, 20, 20000);
  lpf.setFreq(cutoff);
  //HPF
  cutoff = map(mouseY, 0, canvasH, 100, 10000);
  hpf.setFreq(cutoff);
}

/**
 * フルスクリーン
 **/
boolean sketchFullScreen() {
  return isFullscreen;
}

/**
 * 後処理
 **/
void stop()
{
  player.close();
  minim.stop();
  super.stop();
}
