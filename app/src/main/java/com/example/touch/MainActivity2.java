package com.example.touch;

import androidx.appcompat.app.AppCompatActivity;
import androidx.constraintlayout.widget.ConstraintLayout;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;
import android.widget.Button;

public class MainActivity2 extends AppCompatActivity {
    float x;
    float y;
    float X;
    float Y;
    float a;
    float b;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main2);
        ConstraintLayout cl2=(ConstraintLayout) findViewById(R.id.cl2);
        cl2.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View view, MotionEvent motionEvent) {
                x=motionEvent.getX();
                y=motionEvent.getY();

                switch (motionEvent.getAction()){
                    case MotionEvent.ACTION_DOWN:
                        X=x;
                        break;
                    case MotionEvent.ACTION_MOVE:
                        break;
                    case MotionEvent.ACTION_UP:
                        if(x-X>50) {
                            startActivity(new Intent(MainActivity2.this, MainActivity.class));
                        }
                        break;
                    default:
                        throw new IllegalStateException("Unexpected value: " + motionEvent.getAction());
                }
                return true;
            }
        });
        Button bt=(Button) findViewById(R.id.button);

        bt.setOnTouchListener(new View.OnTouchListener() {
            @SuppressLint("ClickableViewAccessibility")
            @Override
            public boolean onTouch(View view, MotionEvent motionEvent) {
                x=motionEvent.getX();
                y=motionEvent.getY();
                X=bt.getX();
                Y=bt.getY();
                switch (motionEvent.getAction()){
                    case MotionEvent.ACTION_DOWN:
                        //a=motionEvent.getX();
                        //b=motionEvent.getY()Y;
                        break;
                    case MotionEvent.ACTION_MOVE:
                        bt.setX(x+X+a);
                        bt.setY(y+Y+b);
                        break;
                    case MotionEvent.ACTION_UP:
                        /*if(x-X>50) {
                            startActivity(new Intent(MainActivity2.this, MainActivity.class));
                        }*/
                        break;
                    default:
                        throw new IllegalStateException("Unexpected value: " + motionEvent.getAction());
                }
                return true;
            }
        });
    }
}