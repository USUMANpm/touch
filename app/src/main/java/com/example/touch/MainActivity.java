package com.example.touch;

import androidx.appcompat.app.AppCompatActivity;
import androidx.constraintlayout.widget.ConstraintLayout;

import android.content.Intent;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;

public class MainActivity extends AppCompatActivity implements View.OnTouchListener{
float x;
float y;
float X;
float Y;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        ConstraintLayout cl=(ConstraintLayout) findViewById(R.id.cs);
        /*cl.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View view, MotionEvent motionEvent) {
                x=motionEvent.getX();
                y=motionEvent.getY();

                switch (motionEvent.getAction()){
                    case motionEvent.ACTION_DOWN:
                        X=x;
                        break;
                    case motionEvent.ACTION_MOVE:
                        break;
                    case motionEvent.ACTION_UP:
                        if(x-X<-50) {

                        }
                        break;
                    default:
                        throw new IllegalStateException("Unexpected value: " + motionEvent.getAction());
                }



                return true;
            }
        });*/
        cl.setOnTouchListener(new View.OnTouchListener() {
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
                        if(x-X<-4) {
                            startActivity(new Intent(MainActivity.this, MainActivity2.class));
                        }
                        break;
                    default:
                        throw new IllegalStateException("Unexpected value: " + motionEvent.getAction());
                }
                return true;
            }
        });
    }

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
                if(x-X<-50) {
                    startActivity(new Intent(MainActivity.this, MainActivity.class));
                }
                break;
            default:
                throw new IllegalStateException("Unexpected value: " + motionEvent.getAction());
        }
        return true;
    }
}