/**
 * Created by AliSawyer on 26/04/2017.
 */
package ui {
import blocks.Block;

import flash.display.Sprite;
import flash.events.TimerEvent;
import flash.geom.Point;
import flash.utils.Timer;
import flash.external.ExternalInterface;
import flash.utils.getQualifiedClassName;

public class Shaker {

	private var toShake:Sprite;
	private var shakerPos:Point;
	private var dir:int = 1;

	public function Shaker(s:Sprite) {
		toShake = s;
	}

	public function initShake() {
		var s:Sprite = this.toShake;
		log('s pos: (' + s.x + ',' + s.y + ')')
		var shakeTimer:Timer = new Timer(150, 10);
		shakeTimer.addEventListener(TimerEvent.TIMER, shake);
		shakeTimer.start();
		log('set timer...')
		if (s is Block) log('id: ' + String((s as Block).getBlockId()))

		this.toShake = s;
		this.shakerPos = new Point(this.toShake.x, this.toShake.y);

		// reset to original position
		shakeTimer.addEventListener(TimerEvent.TIMER_COMPLETE, resetPos);
	}

	private function shake(e:TimerEvent):void {
		dir *= -1;
		//this.toShake.x = this.shakerPos.x + 1.25*dir;
		//this.toShake.y = this.shakerPos.y + 1.25*dir;
		this.toShake.x = this.shakerPos.x + 5.25*dir;
		this.toShake.y = this.shakerPos.y + 5.25*dir;
	}

	private function resetPos(e:TimerEvent) {
		this.toShake.x = this.shakerPos.x;
		this.toShake.y = this.shakerPos.y;
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
