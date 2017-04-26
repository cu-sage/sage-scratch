/**
 * Created by AliSawyer on 22/04/2017.
 */

/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// Hints.as
// Allison Sawyer, April 2017
//

package ui {

import blocks.Block;

import flash.display.DisplayObject;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.TimerEvent;
import flash.external.ExternalInterface;
import flash.geom.Rectangle;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.utils.Timer;
import flash.utils.getQualifiedClassName;

import org.osmf.events.TimeEvent;

import uiwidgets.*;
import flash.geom.Point;

public class Hints extends ScrollFrameContents {

	private static var rulesFile:String;
	private static var rules:Array;
	private static var leftCol:Array;
	private var toShake:Sprite;
	private var shakerPos:Point;
	private var dir:int = 1;

	public function Hints():void {
		rulesFile = '';
	}

	public function getRules():Array {
		return rules;
	}

	public function getRuleBlocks():Array {
		return leftCol;
	}

	public function getRulesFile():void {
		//var h:HintsFlashVar = new HintsFlashVar();
		try {
			rulesFile = root.loaderInfo.parameters.gspResults;
			// open rules file
			var myTextLoader:URLLoader = new URLLoader();
			// set event listener to detect when file is done loading
			myTextLoader.addEventListener(Event.COMPLETE, onLoaded);
			function onLoaded(e:Event):void {
				var rulesData:Array = e.target.data.split(/\n/);
				rules = extractRules(rulesData);
				leftCol = getLeftCol(rules);
			}
			myTextLoader.load(new URLRequest('gsprules'));
		} catch (e:Error) {
			log(String(e));
		}
	}

	private function extractRules(data:Array):Array {
		var allRules:Array = [];
		for each (var line:String in data) {
			// find 2 block names that make up a rule in form <block1> <block2>
			var pattern:RegExp = /<([^>]+)>  <([^>]+)>/g;
			var rule:Array = line.match(pattern);
			// if more than one, only keep first one
			if (rule && rule[0] && rule[0] != '' && allRules.indexOf(rule[0]) < 0) {
				allRules.push(rule[0]);
			}
		}
		return allRules;
	}

	private function getLeftCol(rules:Array):Array {
		var left:Array = [];
		for each (var r:String in rules) {
			var leftAndRight:Array = r.split('  ');
			var toAdd:String = leftAndRight[0];
			// strip angle brackets
			toAdd = strip(toAdd);
			left.push(toAdd);
		}
		return left;
	}

	public function getRightCol(allRules:Array, blockFound:String):Array {
		var rightBlocks:Array = [];
		for each (var r:String in allRules) {
			var leftAndRight:Array = r.split('  ');
			if (strip(leftAndRight[0]) == blockFound && rightBlocks.indexOf(blockFound) < 0) {
				rightBlocks.push(strip(leftAndRight[1]));
			}
		}
		log('rightBlocks: ' + rightBlocks)
		return rightBlocks;
	}

	// strip angle brackets
	private function strip(str:String):String {
		return str.substring(1, str.length - 1);
	}

	public function initShake(s:Sprite) {
		log('initializing shake...')
		var shakeTimer:Timer = new Timer(150, 10);
		shakeTimer.addEventListener(TimerEvent.TIMER, shake);
		shakeTimer.start();
		log('set timer...')

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
}}

