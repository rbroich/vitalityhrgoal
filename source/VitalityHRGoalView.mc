using Toybox.Time;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Attention;
using Toybox.UserProfile;
using Toybox.Application;

enum { // enums for the mGoalSetting
	PT100_HR60_TIME30, // 100 points = average HR>60% for 30min+
	PT200_HR70_TIME30, // 200 points = average HR>70% for 30min+
	PT300_HR70_TIME60, // 300 points = average HR>70% for 60min+
	PT300_HR80_TIME30  // 300 points = average HR>80% for 30min+
}
var mGoalSetting = PT300_HR80_TIME30;
var mGoalSettingTime = 0;

class VitalityHRGoalView extends WatchUi.DataField {
    hidden var mUserMaxHR;
    hidden var mCurrentHR;
    hidden var mAverageHR;
    hidden var mRestingHR;
    hidden var mElapsedTime;
    hidden var mGoalHR;
    hidden var sFractHR;
    hidden var sNumStars;
    hidden var sDuration;
    hidden var mStopBuzzed;

    function initialize() {
        DataField.initialize();
        if (Application has :Storage) { // since 2.4.0
		    mGoalSetting = Application.Properties.getValue("goal_prop");
		    if (mGoalSetting == null) {
		    	mGoalSetting = PT300_HR80_TIME30;
		    }
		}
		mUserMaxHR = 220 - 30;
		if ((UserProfile has :getHeartRateZones) && (UserProfile has :getCurrentSport)) { // since 1.2.6
        	var hrzones = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
        	mUserMaxHR = hrzones[5]; // maximum heart rate threshold for zone 5; should be 100% of user settable max heart rate
        }
		mRestingHR = 60;
		if (UserProfile has :getProfile) {
			var profile = UserProfile.getProfile();
	        if ((profile has :restingHeartRate) && (profile.restingHeartRate != null)) {
	            mRestingHR = profile.restingHeartRate;
	        }
        }
        mGoalSettingTime = 0;
        mGoalHR = 0;
        sFractHR = 0.8;
        sNumStars = 3;
        sDuration = 30*60;
        mStopBuzzed = 0;
		//System.println("The goal setting is " + mGoalSetting);
		//System.println("The users max HR is " + mUserMaxHR);
		//System.println("The users resting HR is " + mRestingHR);
    }

    function compute(info) {
        mCurrentHR = 0;
        if ((info has :currentHeartRate) && (info.currentHeartRate != null)) {
            mCurrentHR = info.currentHeartRate;
        }
        mAverageHR = 0;
        if ((info has :averageHeartRate) && (info.averageHeartRate != null)) {
            mAverageHR = info.averageHeartRate;
        }
        mElapsedTime = 0;
        if ((info has :elapsedTime) && (info.elapsedTime != null)) {
            mElapsedTime = info.elapsedTime / 1000; // ms to seconds
        }

		switch (mGoalSetting) { // lookup the goals based on the current setting
			case PT100_HR60_TIME30: sFractHR=0.6; sNumStars=1; sDuration=30*60; break;
			case PT200_HR70_TIME30: sFractHR=0.7; sNumStars=2; sDuration=30*60; break;
			case PT300_HR70_TIME60: sFractHR=0.7; sNumStars=3; sDuration=60*60; break;
			default: sFractHR=0.8; sNumStars=3; sDuration=30*60; break;
		}
		mGoalHR = mUserMaxHR*sFractHR;
		var remaining_time = sDuration - mElapsedTime;
		if (remaining_time > 0) { // don't divide by 0
			mGoalHR = (mUserMaxHR*sFractHR*sDuration - mElapsedTime*mAverageHR) / remaining_time;
		}
		if ((remaining_time == 0) && (mAverageHR >= mUserMaxHR*sFractHR)) { // goal reached
        	if (Attention has :vibrate) {
        		Attention.vibrate([new Attention.VibeProfile(100, 300), new Attention.VibeProfile(0, 200), new Attention.VibeProfile(100, 300)]);
        	}
		}
		if (mGoalHR < mRestingHR) { // don't allow negative goals, or any less than the resting heart rate
			mGoalHR = mRestingHR;
		}
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
    	var star_color = 0;
        var remaining_sec = sDuration - mElapsedTime;
        if (Time.now().value() - mGoalSettingTime <= 2) { // settings changed within the last 2 seconds
        	var goalstring = "";
			switch (mGoalSetting) {
				case PT100_HR60_TIME30: goalstring = "100 points:\nHR>60% for 30min+"; break;
				case PT200_HR70_TIME30: goalstring = "200 points:\nHR>70% for 30min+"; break;
				case PT300_HR70_TIME60: goalstring = "300 points:\nHR>70% for 60min+"; break;
				default: goalstring = "300 points:\nHR>80% for 30min+"; break;
			}
    		dc.drawText(dc.getWidth()/2, dc.getHeight()/2, Graphics.FONT_XTINY, goalstring, (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));
        } else if (remaining_sec > 0) {
			var remaining_min = Math.ceil(remaining_sec / 60.0);
        	dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
    		dc.drawText(dc.getWidth()/2, dc.getFontHeight(Graphics.FONT_TINY)/2, Graphics.FONT_TINY, "Goal HR", (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));
    		dc.drawText(dc.getWidth()-35, dc.getHeight()-dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM)/2+5, Graphics.FONT_TINY, remaining_min.format("%02d")+"m", (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));
    		dc.drawText(dc.getWidth()/2, dc.getHeight()-dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM)/2, Graphics.FONT_NUMBER_MEDIUM, mGoalHR.format("%d"), (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));

			var hr_diff = mCurrentHR - mGoalHR;
			if (hr_diff < 0) {
        		dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        	} else if (hr_diff < 3) {
        		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        	} else {
        		dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        	}
        	dc.drawText(dc.getWidth()-35, dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM)/2-5, Graphics.FONT_NUMBER_MEDIUM, hr_diff.format("%+d"), (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));
        	
        	star_color = Graphics.COLOR_YELLOW;
        } else if (remaining_sec > -2) {
        	if (mAverageHR >= mGoalHR) {
        		dc.drawText(dc.getWidth()/2, dc.getHeight()/2, Graphics.FONT_SMALL, "Goal\nReached", (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));
        	} else {
        		dc.drawText(dc.getWidth()/2, dc.getHeight()/2, Graphics.FONT_SMALL, "Missed\nGoal", (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));
        	}
        } else { // time reached
			var hr_diff = mAverageHR - mGoalHR;
			if ((hr_diff >= 0) && (hr_diff <= 1) && (mStopBuzzed == 0)) {
				mStopBuzzed = 1;
        		dc.drawText(dc.getWidth()/2, dc.getHeight()/2, Graphics.FONT_TINY, "Ave HR dropping\nbelow Goal", (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));
	        	if (Attention has :vibrate) {
	        		Attention.vibrate([new Attention.VibeProfile(100, 800), new Attention.VibeProfile(0, 400), new Attention.VibeProfile(100, 800)]);
	        	}
			} else {
	        	if (mAverageHR >= mGoalHR) {
	        		star_color = Graphics.COLOR_GREEN;
	        	} else {
	        		star_color = Graphics.COLOR_RED;
	        	}
	        	dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
	    		dc.drawText(dc.getWidth()/2, dc.getFontHeight(Graphics.FONT_TINY)/2, Graphics.FONT_TINY, "Ave. HR", (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));
	    		dc.drawText(dc.getWidth()/2, dc.getHeight()-dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM)/2, Graphics.FONT_NUMBER_MEDIUM, mAverageHR.format("%d"), (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));
	    		var elapsed_min = mElapsedTime / 60;
	    		dc.drawText(dc.getWidth()-35, dc.getHeight()-dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM)/2+5, Graphics.FONT_TINY, elapsed_min.format("%02d")+"m", (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));

				if (hr_diff < 0) {
	        		dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
	        	} else if (hr_diff < 2) {
	        		dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
	        	} else {
	        		dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
	        	}
	        	dc.drawText(dc.getWidth()-35, dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM)/2-5, Graphics.FONT_NUMBER_MEDIUM, hr_diff.format("%+d"), (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));
    		}
        }
        
        if (star_color != 0) { // draw goal star
			var x=35;
			var y=dc.getHeight()/2;
			dc.setColor(star_color, Graphics.COLOR_TRANSPARENT);
			dc.fillPolygon([ [x-27,y-6],[x-8,y-9],[x+1,y-26],[x+9,y-9],[x+28,y-6],[x+14,y+8],[x+17,y+26],[x+0,y+18],[x-16,y+26],[x-13,y+8] ]); // w=57,h=52
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.drawText(x, y, Graphics.FONT_TINY, sNumStars.format("%d"), (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER));
		}
    }
}


class VitalityHRGoalDelegate extends WatchUi.InputDelegate {
    function initialize() {
        InputDelegate.initialize();
    }

    function onTap(evt) {
    	mGoalSetting += 1;
    	if (mGoalSetting > PT300_HR80_TIME30) {
    		mGoalSetting = PT100_HR60_TIME30;
    	}
	    mGoalSettingTime = Time.now().value();
    	if (Application has :Storage) { // since 2.4.0
	        Application.Properties.setValue("goal_prop", mGoalSetting);
    	}
    }
}

