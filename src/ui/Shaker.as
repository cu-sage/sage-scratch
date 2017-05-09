/**
 * Created by AliSawyer on 26/04/2017.
 */
package ui {
import blocks.Block;

import flash.display.Graphics;

import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.filters.GlowFilter;
import flash.geom.Point;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.utils.Timer;
import flash.external.ExternalInterface;
import flash.utils.getQualifiedClassName;

public class Shaker {

	private var sprite:Sprite;
	private var toShake:Sprite;
	private var shakerPos:Point;
	private var dir:int = 1;
	private var shakeTimer:Timer;

	// for yellow highlight
	private static var toggle:int = 0;
	private static var colorTimer:Timer;

	public function Shaker(s:Sprite) {
		sprite = s;
	}

	public function initShake(cat:int = 0) {
		var s:Sprite = this.sprite;
		shakeTimer = new Timer(150, 10);
		shakeTimer.addEventListener(TimerEvent.TIMER, shake);
		shakeTimer.start();

		this.toShake = s;
		// stop shaking if user clicks on hinted block/category
		this.toShake.addEventListener(MouseEvent.CLICK, resetPos);
		this.toShake.addEventListener(MouseEvent.MOUSE_DOWN, resetPos);
		this.shakerPos = new Point(this.toShake.x, this.toShake.y);

		if (cat == 1 && !colorTimer || (colorTimer && !colorTimer.hasEventListener(TimerEvent.TIMER))) {
			toggle = 0;
			changeColor(); // category only for now
		}

		// reset to original position
		shakeTimer.addEventListener(TimerEvent.TIMER_COMPLETE, resetPos);
	}

	private function shake(e:TimerEvent):void {
		dir *= -1;
		// change the value multiplied by 'dir' to change amount shaking moves the object
		// higher value --> more movement
		this.toShake.x = this.shakerPos.x + 2*dir;
		this.toShake.y = this.shakerPos.y + 2*dir;
	}

	public function resetPos(e:Event) {
		this.toShake.x = this.shakerPos.x;
		this.toShake.y = this.shakerPos.y;
		shakeTimer.removeEventListener(TimerEvent.TIMER, shake);
		shakeTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, resetPos);
	}

	public function changeColor() {
		afterColorTimer();
		colorTimer = new Timer(500, 3);
		colorTimer.start();
		colorTimer.addEventListener(TimerEvent.TIMER, afterColorTimer);
		colorTimer.addEventListener(TimerEvent.TIMER_COMPLETE, endChangeColor);
	}

	private function afterColorTimer(evt:TimerEvent = null) {
		this.toShake = this.sprite;
		var catText:TextField = this.toShake.getChildAt(0) as TextField;
		if (toggle++ % 2 == 0) {
			var color:Number = 0xffff00;
			var gf:GlowFilter = new GlowFilter(color);
			gf.alpha = 0.8;
			gf.blurX = 20;
			gf.blurY = 25;
			gf.strength = 4;
			gf.inner = false;
			if (catText) catText.filters = [gf];
		} else {
			if (catText) catText.filters = [];
		}
	}

	private function endChangeColor(e:Event = null) {
		if (colorTimer && colorTimer.hasEventListener(TimerEvent.TIMER))
			colorTimer.removeEventListener(TimerEvent.TIMER, afterColorTimer);
		if (colorTimer && colorTimer.hasEventListener(TimerEvent.TIMER_COMPLETE))
			colorTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, endChangeColor);
	}

	public function log(msg:String, caller:Object = null):void {
		var str:String = "";
		if(caller){
			str = getQualifiedClassName(caller);
			str += ":: ";
		}
		str += msg;
		trace(str);
		if(ExternalInterface.available){
			ExternalInterface.call("console.log", str);
		}
	}
}
}
