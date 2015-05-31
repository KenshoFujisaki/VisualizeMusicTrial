// output: Visualize music with processing and kinect interaction - Gillionaire - YouTube - https://www.youtube.com/watch?v=i5dgmsorDss

import ddf.minim.*;
import ddf.minim.effects.*;
import ddf.minim.analysis.*;
import java.util.Map;
import java.util.Iterator;
import SimpleOpenNI.*;

//キャンバス
int canvasW = 640;
int canvasH = 480;
int canvasFPS = 30;
boolean isFullscreen = false;

//音声入力
String audioFilepath = "audio.mp3";
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
DownGain down;
float maxGain = 2.0;

//Kinect
SimpleOpenNI context;
int handVecListSize = 20;
Map<Integer,ArrayList<PVector>>  handPathList = new HashMap<Integer,ArrayList<PVector>>();
color[] userClr = new color[]{ color(255,0,0),
  color(0,255,0),
  color(0,0,255),
  color(255,255,0),
  color(255,0,255),
  color(0,255,255)
};

/**
 * Gain
 * ref: http://www.pronowa.com/room/sound003.html
 **/
class DownGain implements AudioEffect
{
  float gain = 1.0;
  DownGain(float g) {
    gain = g;
  }
  public void setGain(float g) {
    gain = g;
  }
  void process(float[] samp) {
    float[] out = new float[samp.length];
    for ( int i = 0; i < samp.length; i++ ) {
      out[i] = samp[i] * gain;
    }
    arraycopy(out, samp);
  }
  void process(float[] left, float[] right) {
    process(left);
    process(right);
  }
}

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
  background(0);

  //音声再生
  minim = new Minim(this);
  player = minim.loadFile(audioFilepath, BUFSIZE);
  player.loop();

  //FFT
  fft = new FFT(player.bufferSize(), player.sampleRate());

  //エフェクト
  lpf = new LowPassSP(20000, player.sampleRate());
  hpf = new HighPassSP(0, player.sampleRate());
  down = new DownGain(1.0);
  player.addEffect(lpf);
  player.addEffect(hpf);
  player.addEffect(down);

  //回転角
  for (int i = 0; i < BUFSIZE; i++) {
    rot[i] = random(0, 360);
    rotSpeed[i] = 0;
  }

  //Kinect
  context = new SimpleOpenNI(this);
  if(context.isInit() == false)
  {
     println("Can't init SimpleOpenNI, maybe the camera is not connected!"); 
     exit();
     return;
  }
  context.enableDepth();
  context.setMirror(true);
  context.enableHand();
  context.startGesture(SimpleOpenNI.GESTURE_WAVE);
}

/**
 * 描画
 **/
void draw(){
  //Kinect
  context.update();
  image(context.depthImage(), 0, 0); //深度画像
  if(handPathList.size() > 0) {
    Iterator itr = handPathList.entrySet().iterator();
    while(itr.hasNext()) {
      Map.Entry mapEntry = (Map.Entry)itr.next(); 
      int handId =  (Integer)mapEntry.getKey();
      ArrayList<PVector> vecList = (ArrayList<PVector>)mapEntry.getValue();
      PVector p;
      PVector p2d = new PVector();
      stroke(userClr[ (handId - 1) % userClr.length ]);
      noFill(); 
      strokeWeight(1);
      Iterator itrVec = vecList.iterator(); 
      beginShape();
      while( itrVec.hasNext() ) {
        p = (PVector) itrVec.next();
        context.convertRealWorldToProjective(p,p2d);
        vertex(p2d.x,p2d.y);
      }
      endShape();
      stroke(userClr[ (handId - 1) % userClr.length ]);
      strokeWeight(4);
      p = vecList.get(0);
      context.convertRealWorldToProjective(p,p2d);
      point(p2d.x,p2d.y);

      //HPF
      float cutoff = map(p2d.x, 0, canvasH, 100, 5000);
      hpf.setFreq(cutoff);

      //LPF
      //cutoff = map(p2d.x, 0, canvasW, 0, 20000);
      //lpf.setFreq(cutoff);

      //Gain
      cutoff = map(p2d.y, 0, canvasW, 0, maxGain);
      down.setGain(maxGain - cutoff);
    }
  }

  // FFT
  translate(width/2, height/2);
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
    float h = map(i, 0, specSize, 50, 200);
    float fillColor = h * colorCoef;
    fill(fillColor, fillColor, fillColor, 50);
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
 * フルスクリーン
 **/
boolean sketchFullScreen() {
  return isFullscreen;
}

/**
 * hand events
 * ref: https://code.google.com/p/simple-openni/source/browse/trunk/SimpleOpenNI-2.0/dist/all/SimpleOpenNI/examples/OpenNI/Hands/Hands.pde?r=440
 **/
void onNewHand(SimpleOpenNI curContext,int handId,PVector pos) {
  println("onNewHand - handId: " + handId + ", pos: " + pos);
  ArrayList<PVector> vecList = new ArrayList<PVector>();
  vecList.add(pos);
  handPathList.put(handId,vecList);
}

void onTrackedHand(SimpleOpenNI curContext,int handId,PVector pos) {
  //println("onTrackedHand - handId: " + handId + ", pos: " + pos );
  ArrayList<PVector> vecList = handPathList.get(handId);
  if(vecList != null) {
    vecList.add(0,pos);
    if(vecList.size() >= handVecListSize)
      // remove the last point
      vecList.remove(vecList.size()-1); 
  }
}

void onLostHand(SimpleOpenNI curContext,int handId) {
  println("onLostHand - handId: " + handId);
  handPathList.remove(handId);
}

/**
 * gesture events
 * ref: https://code.google.com/p/simple-openni/source/browse/trunk/SimpleOpenNI-2.0/dist/all/SimpleOpenNI/examples/OpenNI/Hands/Hands.pde?r=440
 **/
void onCompletedGesture(SimpleOpenNI curContext,int gestureType, PVector pos) {
  println("onCompletedGesture - gestureType: " + gestureType + ", pos: " + pos);
  
  int handId = context.startTrackingHand(pos);
  println("hand stracked: " + handId);
}

/**
 * Keyboard events
 * ref: https://code.google.com/p/simple-openni/source/browse/trunk/SimpleOpenNI-2.0/dist/all/SimpleOpenNI/examples/OpenNI/Hands/Hands.pde?r=440
 **/
void keyPressed() {
  switch(key)
  {
  case ' ':
    context.setMirror(!context.mirror());
    break;
  case '1':
    context.setMirror(true);
    break;
  case '2':
    context.setMirror(false);
    break;
  }
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
