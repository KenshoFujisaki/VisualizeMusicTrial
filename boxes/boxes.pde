// ref: 3. Yasushi Noguchi Class - http://r-dimension.xsrv.jp/classes_j/3_interactive3d/

import ddf.minim.analysis.*;
import ddf.minim.*;

//キャンバス
int canvasW = 1400;
int canvasH = 800;
int canvasFPS = 3;

//音声入力
int BUFSIZE = 1024;   //最大音量
Minim minim;
AudioInput in;
FFT fft;

//全体回転角
float coefficient = 0.005;
float globalRotate = 0;
float globalRotateConst = 0.2;

//各箱情報
float[][] boxFeature;

//立方体
float boxSize = 100;
float distance = 180;
float halfDis;
int boxNum = 3;

/**
 * フルスクリーン
 **/
boolean sketchFullScreen() {
  return true;
}

/**
 * 初期化
 **/
void setup(){
  size(canvasW, canvasH, P3D);
  colorMode(HSB, 360, 100, 100, 70);
  halfDis = distance * (boxNum-1) / 2;

  //音声入力
  minim = new Minim(this);
  in = minim.getLineIn(Minim.STEREO, BUFSIZE);
  fft = new FFT(in.bufferSize(), in.sampleRate());

  //各箱情報
  boxFeature = new float[boxNum * boxNum * boxNum][2];
}

/**
 * 描画
 **/
void draw(){
  //背景色設定
  background(0);
  translate(width/2, height/2);
  fill(255, 255, 255);

  // FFT
  fft.forward(in.mix);
  float specSize = fft.specSize();  //周波数幅
  int counter = 0;
  float totalVolume = 0;
  for (int i = 0; i < specSize; i++) {
    if (i % ((int)specSize / (boxNum * boxNum * boxNum)) != 0) {
      continue;
    }

    //各周波数における音量 -> 各箱における回転角
    float getBand = fft.getBand(i);
    float boxLength = map(getBand, 0, BUFSIZE/16, 0, boxSize);
    boxFeature[counter][0] = log(boxLength) * 30;

    //累積音量 -> 全体回転角
    totalVolume += getBand;

    //周波数 -> 色相
    float h = map(i, 0, specSize, 0, 255);
    boxFeature[counter][1] = h;

    counter++;
  }

  //累計音量 -> 全体回転量
  globalRotate += totalVolume * coefficient + globalRotateConst;
  if(globalRotate > 360) {
    globalRotate -= 360;
  }
  rotateX(radians(globalRotate));
  rotateY(radians(globalRotate));
  rotateZ(radians(globalRotate));

  for(int z = 0; z < boxNum; z ++){
    for(int y = 0; y < boxNum; y ++){
      for(int x = 0; x < boxNum; x ++){
        pushMatrix();

        //座標
        translate(
            x * distance - halfDis, 
            y * distance - halfDis, 
            z * distance - halfDis);
        int offset = x * boxNum * boxNum + y * boxNum + z;

        //色
        float offsetLoop = offset + abs(globalRotate - 180) * 0.1;
        float h = map(offsetLoop, 0, boxNum * boxNum * boxNum, 30, 250);
        fill(h, h, h, 25);

        //サイズ
        float c = max(5, boxFeature[offset][0]) + 20;
        box(c, c, c);
        noStroke();

        //フィルタ
        //filter(BLUR, 10);

        popMatrix();
      }
    }
  }
}
