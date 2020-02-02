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

// Scratch.as
// John Maloney, September 2009
//
// This is the top-level application.

package {
import blocks.*;

import extensions.ExtensionManager;
import flash.display.*;
import flash.errors.IOError;
import flash.errors.IllegalOperationError;
import flash.events.*;
import flash.events.IOErrorEvent;
import flash.external.ExternalInterface;
import util.JSON;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.net.FileReference;
import flash.net.FileReferenceList;
import flash.net.LocalConnection;
import flash.net.SharedObject;
import flash.net.Socket;
import flash.net.URLLoader;
import flash.net.URLLoaderDataFormat;
import flash.net.URLRequest;
import flash.net.URLRequestMethod;
import flash.system.*;
import flash.text.*;
import flash.utils.*;
import interpreter.*;
import render3d.DisplayObjectContainerIn3D;
import scratch.*;
import translation.*;
import ui.*;
import ui.media.*;
import ui.parts.*;
import uiwidgets.*;
import util.*;
import watchers.ListWatcher;
import util.Logger;

public class Scratch extends Sprite {
	// Version
	public static const versionString:String = 'v426';
	public static var app:Scratch; // static reference to the app, used for debugging

	// Display modes
	public var editMode:Boolean; // true when project editor showing, false when only the player is showing
	public var isOffline:Boolean; // true when running as an offline (i.e. stand-alone) app
	public var isSmallPlayer:Boolean; // true when displaying as a scaled-down player (e.g. in search results)
	public var stageIsContracted:Boolean; // true when the stage is half size to give more space on small screens
	public var isIn3D:Boolean;
	public var render3D:IRenderIn3D;
	public var isArmCPU:Boolean;
	public var jsEnabled:Boolean = false; // true when the SWF can talk to the webpage

	// Runtime
	public var runtime:ScratchRuntime;
	public var interp:Interpreter;
	public var extensionManager:ExtensionManager;
	public var server:Server;
	public var gh:GestureHandler;
	public var projectID:String = '';
	public var projectOwner:String = '';
	public var projectIsPrivate:Boolean;
	public var oldWebsiteURL:String = '';
	public var loadInProgress:Boolean;
	public var debugOps:Boolean = false;
	public var debugOpCmd:String = '';

	protected var autostart:Boolean;
	private var viewedObject:ScratchObj;
	private var lastTab:String = 'scripts';
	protected var wasEdited:Boolean; // true if the project was edited and autosaved
	private var _usesUserNameBlock:Boolean = false;
	protected var languageChanged:Boolean; // set when language changed

	// UI Elements
	public var playerBG:Shape;
	public var palette:BlockPalette;
	public var paletteBuilder:PaletteBuilder;
	public var scriptsPane:ScriptsPane;
	public var stagePane:ScratchStage;
	public var mediaLibrary:MediaLibrary;
	public var lp:LoadProgress;
	public var cameraDialog:CameraDialog;

	// UI Parts
	public var libraryPart:LibraryPart;
	protected var topBarPart:TopBarPart;
	protected var stagePart:StagePart;
	private var tabsPart:TabsPart;
	// protected var scriptsPart:ScriptsPart;
	public var scriptsPart:ScriptsPart;
	public var imagesPart:ImagesPart;
	public var soundsPart:SoundsPart;
	public const tipsBarClosedWidth:int = 17;

    // jw3564: socket
    private var client:Socket;
    private var socketIsConnected:Boolean=false;

	// Block IDs
	public var blockIdCt:int = 0;

	// Points
	public var totalMoves:int=0;
    public var meaningfulMoves:int=0;
    public var blocksCount:int=0;
    public var success:Boolean=false;
	public var maxScore:int;
    public var maxScoreForGame:int=0;
    public var cutoff1:int=0;
	public var cutoff2:int=0;
    public var selfExplanation:String;
    public var map:Object = {};

    // jw3564: remainingTime in seconds
    private var completed:Boolean = false;
    private var startTime:String;

	//can be changed to array of messages if required in future
    public var submitMsg:String;

    private var hasDuplicateResponse:Object={};
    private var hasConfigResponse:Object={};

	// Game data
    private var queryParams:Object;
    private var sid:String;
    private var assignmentID:String="";
	private var objectiveID:String="";
    private var mode:String;
	private var baseUrl:String;
	private var gameType:String;

    private var tick:int = 0;
    private var doSave:Boolean=false;

	public function getDoSave():Boolean{
		return this.doSave;
	}

	public function setDoSave(state:Boolean):void{
		this.doSave = state;
	}

    public function getMode():String {
        return this.mode;
    }

	protected var points:int = 0;
	public function setPoints(points:int):void {
		this.points = points;
	}

	public function getPoints():int {
		return points;
	}

	public function incrementPoints(pointsToAdd:int):void {
		setPoints(this.points + pointsToAdd);
		stagePart.updatePointsLabel();
	}

	public function decrementPoints(pointsToSubtract:int):void {
		setPoints(this.points - pointsToSubtract);
		stagePart.updatePointsLabel();
	}

    public function sendUpdatedPointsToServer(): void {
        trace("send updated score");

        var payload:Object = {};
        payload.isFinal = completed;
        payload.event = "UPDATE_POINT";
        payload.studentID = sid;
        payload.assignmentID = assignmentID;
        payload.objectiveID = objectiveID;
        payload.timestamp = new Date().valueOf().toString();
        payload.newPoint = getPoints().toString();
        payload.feedback = stagePart.getMessageLabelText();
        payload.firstBlock = prevBlock; 
        payload.wrongBlock = wrongBlock;
        payload.correctBlock = correctBlock;
        payload.feedbackSignal = feedbackSignal;
        payload.colorFlag = colorFlag;
        payload.updateFlag = updateFlag;
        payload.meaningfulMoves = meaningfulMoves;
        payload.maxScoreForGame = maxScoreForGame;

        trace(payload.newPoint);
        var stringPayload:String = util.JSON.stringify(payload);
        // send updated score to the server via socket
        try {
            client.writeUTFBytes(stringPayload);
            Logger.logBrowser(stringPayload.slice(1, stringPayload.length-1).split("\n").join(""));
            client.flush();
        } catch (e) {
            trace("socket error: " + e.toString());
        }
    }

    public function sendStudentFeedback():void {

        var payload:Object = {};
        payload.event = "SEND_FEEDBACK";
        payload.studentID = sid;
        payload.assignmentID = assignmentID;
        payload.firstBlock = prevBlock;
        payload.correctBlock = correctBlock;
        payload.wrongBlock = wrongBlock;

        var d:DialogBox = new DialogBox(null);
        d.addTitle('Peer assistance');
        d.addText('Explain how you arrived at the correct block after having chosen a wrong one and get a point back!');
        d.addField('Enter Explanation', 300, payload.feedback);
        d.addButton('Ok', ok);
        d.addButton('Cancel',null);
        d.showOnStage(app.stage);
        getFeedback = false;

        function ok():void {
            payload.feedback = d.getField('Enter Explanation');
            if(payload.feedback != null){
                incrementPoints(1);
                sendUpdatedPointsToServer();
                paletteBuilder.showBlocksForCategory(Specs.parsonsCategory, false);
            }
            var stringPayload:String = util.JSON.stringify(payload);
            try {
                client.writeUTFBytes(stringPayload);
                Logger.logBrowser(stringPayload.slice(1, stringPayload.length-1).split("\n").join(""));
                client.flush();
            } catch (e) {
                trace("socket error: " + e.toString());
            }    
        }
    }

    public function getInstructorFeedback(): void {

        var payload:Object = {};
        payload.event = "SEND_INSTRUCTOR_FEEDBACK";
        payload.assignmentID = assignmentID;
        
        var temp:Block = viewedObject.scripts[0] as Block;
        while(temp.nextBlock != null){
            payload.firstBlock = temp.op;
            payload.wrongBlock = temp.nextBlock.op;
            temp = temp.nextBlock;
        }

        var d:DialogBox = new DialogBox(null);
        d.addTitle('Instructor Feedback');
        d.addText('give additional feedback when the student arrives at your current solution');
        d.addField('Enter Explanation', 300, payload.feedback);
        d.addButton('Ok', ok);
        d.addButton('Cancel',null);
        d.showOnStage(app.stage);

        function ok():void {
            payload.feedback = d.getField('Enter Explanation');
            var stringPayload:String = util.JSON.stringify(payload);
            try {
                client.writeUTFBytes(stringPayload);
                Logger.logBrowser(stringPayload.slice(1, stringPayload.length-1).split("\n").join(""));
                client.flush();
            } catch (e) {
                trace("socket error: " + e.toString());
            }    
        }

    }

    public function submitProject():void {
        var projIO:ProjectIO = new ProjectIO(this);
        var zipData:ByteArray = projIO.encodeProjectAsZipFile(stagePane);

        function ok():void {
            submitMsg = d.getField("Submit Message");
            storeUpdatedGameSetting();

            uploadToServer(zipData);


            var notice:DialogBox = new DialogBox(null);
            notice.addTitle("Saving Project Succeed!");
            notice.addText("Your question is: " + paletteBuilder.getQuestion() +
                    ".\n Your hint is: " + paletteBuilder.getHint() +
                    ".\n Time set for this question is: " + paletteBuilder.getInputTime()+
                    ".\n The Basic cutoff score is: " + cutoff1 +
                    ".\n The Developing cutoff score is: " + cutoff2 +
                    ".\n The Proficient cutoff score is: " + maxScore +
                    ".\n Your submission message is: " + submitMsg +
                    ".\n Your puzzle has been saved too." +
                    ".\n You can make any change and save again to overwrite.");
            notice.addButton('Close', null);
            notice.showOnStage(app.stage);
        }

        var d:DialogBox = new DialogBox(null);
        d.addTitle('Submit Message');
        d.addField('Submit Message', 200, submitMsg);
        d.addButton('Ok', ok);
        d.addButton('Cancel',null);
        d.showOnStage(app.stage);

    }

    public function submitStudentGame(): void {
		//exportProjectToFile();
        sendUpdatedPointsToServer();
        exportProjectToServer();
		
    }

    public function addScore(b:Block):void{
        if(b != null){
            addScore(b.subStack1);
            addScore(b.subStack2);
			maxScore += b.pointValue;
		}
    }

    public function getCutoffScores():void {
        function ok():void {
            cutoff1 = d.getField("Basic");
            cutoff2 = d.getField("Developing");

            if (cutoff1 > cutoff2) {
                var errorMsg:DialogBox = new DialogBox(null);
                errorMsg.addTitle("Setting cutoff scores failed!");
                errorMsg.addText("The Basic cutoff score could not be larger than the Developing cutoff score");
                errorMsg.addButton("Close", null);
                errorMsg.showOnStage(app.stage);
                cutoff1 = 0;
                cutoff2 = 0;
            } else {
                var currScript:Array = viewedObject.scripts;
                var i:int;
                for (i = 0; i < currScript.length; i++) {
                    var b:Block = currScript[i] as Block;
                    while(b != null){
                        addScore(b.subStack1);
                        addScore(b.subStack2);
                        maxScore += b.pointValue;
                        b = b.nextBlock;
                    }
                }
                submitProject();
            }
        }

        var d:DialogBox = new DialogBox(null);
        d.addTitle('Scores');
        d.addField('Basic', 50, cutoff1);
        d.addField('Developing', 50, cutoff2);
        d.addButton('Ok', ok);
        d.addButton('Cancel',null);
        d.showOnStage(app.stage);
    }

	public static const K_NOT_DRAGGED_FROM_PALETTE_OR_SCRIPTS_PANE:int = 0;
	public static const K_DRAGGED_FROM_PALETTE:int = 1;
	public static const K_DRAGGED_FROM_SCRIPTS_PANE:int = 2;

	//for detecting where a block you're currently dragging was dragged from. For determining if points should be added/subtracted.
	public var blockDraggedFrom = K_NOT_DRAGGED_FROM_PALETTE_OR_SCRIPTS_PANE;

	//parsons logic
    public var getFeedback:Boolean = false;
    public var wrongState:Boolean = false;
    public var firstWrongState:Boolean = false;
    public var wrongBlock:String = "";
    public var correctBlock:String = "";
    public var prevBlock:String = "";
    public var correct:Boolean = true;
    public var expectDummyCheck:Boolean = false;
    public var expectRemoval:Boolean = false;
    public var currPb:String = "pbIsNull";
    public var correctSb:String = "sbIsNull";
    public var notComplete:Boolean = false;
    public var feedbackSignal:String  = "";
    public var updateFlag:Number = 1;
    public var colorFlag:Number = 2;

    // per block feedback
    public var correctFeedback:Array = [];
    public var incorrectFeedback:Array = [];
    public var neutralFeedback:Array = [];
    public var potentialFeedback:Array = [];

    public function playSolution():void{

        function startIfGreenFlag(stack:Block, target:ScratchObj):void {
            if (stack.op == 'whenGreenFlag') interp.toggleThread(stack, target);
        }

        for each (var stack in viewedObject.parsonScripts){
            startIfGreenFlag(stack, viewedObject);
        }
        autoInitialize();

    }

    public function getParents(sb, id, sop): Array{

        var arr:Array = BlockIO.stackToArrayOnlySubstacks(sb);
//        trace("--------parent array-------");
//        for (var i = 0; i < arr.length; i ++) trace(arr[i].op);
//        trace("----------");

        if(sop == null){
            return [];
        }

        var op:String = sop.op;

        var toReturn:Array = [];
        var count:int = 0;
        var comp:String = op;

        if(id){
            comp = id;
        }

        var prev:Block = null;
        trace("-----to return-----");
        while(arr != null && count < arr.length){
            var comp2:String = arr[count].op;
            if(id){
                comp2 = arr[count].id;
            }

            var down:Block = count + 1 < arr.length ? arr[count + 1] : null;
            if(comp == comp2) {
                trace("#####");
                toReturn.push({up: prev, block: arr[count], down: down});
                trace("prev:");
                try {
                    trace(prev.op);
                } catch (e) {}
                trace("down:");
                try {
                    trace(down.op);
                } catch (e) {}
                trace("arr[]:");
                try {
                    trace(arr[count].op);
                } catch (e) {}

                trace("#####");
            }

            prev = arr[count];
            count += 1;
        }
        trace("len: " + toReturn.length);
        trace('---------');

//        trace("--------to return array-------");
//        trace(toReturn.toString());
//        trace("----------");
        return toReturn;

    }

    public function getStatusOfBlock(realParents:Array, newParents:Array):int {

        var maxStatus:int = -1;

//        for each (var curObj:Object in newParents){
//            for each (var realObj:Object in realParents){
//                if(curObj.up == null && curObj.down == null){
//                    return -1;
//                }
//
//                var curScore:int = 0;
//                if (realObj.up && curObj.up && realObj.up.op == realObj.up.op) {
//                    curScore += 1;
//                } else if (!realObj.up && !curObj.up) {
//                    if (realObj.down && realObj.down == curObj.down) {
//                        curScore += 1;
//                    }
//                }
//
//                if (realObj.down && curObj.down && realObj.down.op == realObj.down.op) {
//                    curScore += 1;
//                } else if (!realObj.down && !curObj.down) {
//                    if (realObj.up && realObj.up == curObj.up) {
//                        curScore += 1;
//                    }
//                }
//
//
//                if(curScore > maxStatus){
//                    maxStatus  = curScore;
//                }
//            }
//        }

        for each (var tr:Object in newParents){

            for each (var trr:Object in realParents){


                if(tr.up == null && tr.down == null){
                    return -1;
                }

                var curScore:int = 0;
                if(trr.up){
                    if(tr.up){
                        if(tr.up.op == trr.up.op){
                            curScore += 1;
                        }
                    }
                }else{
                    if(!tr.up){
                        curScore += 1;
                    }
                }


                if(trr.down){
                    if(tr.down){
                        if(tr.down.op == trr.down.op){
                            curScore += 1;
                        }
                    }
                }else{
                    if(!tr.down){
                        curScore += 1;
                    }
                }

                if(curScore > maxStatus){
                    maxStatus  = curScore;
                }
            }

        }

        return maxStatus;
    }

    public function calSimilarity(parsonScript:Array, currScript:Array):Number {
        var similarity:Number = 0;

        var parsonArr:Array = BlockIO.stackToArrayOnlySubstacks(parsonScript[0] as Block);
        var currArr:Array = BlockIO.stackToArrayOnlySubstacks(currScript[0] as Block);

        var visited:Array = new Array(parsonArr.length);
        for each(var v:Boolean in visited) { v = false; }

        var sameCnt:int = 0;
        for each(var currBlock:Block in currArr) {
            for (var i = 0; i < parsonArr.length; i ++) {
                var parsonBlock:Block = parsonArr[i];
                if (!visited[i] && parsonBlock.op == currBlock.op) {
                    sameCnt ++;
                    visited[i] = true;
                }
            }
        }
        similarity = int(100 * sameCnt / parsonArr.length) / 100;
        return similarity;
    }
    
	// feedback here
    public function parsonsLogic(adding:Boolean):void {

		setPoints(0);
        trace("-----recent block------");
        try {
            trace(viewedObject.recentBlock.op);
        } catch (e) {
            
        }
        trace("--------");
		// script from json
		var scripts:Array = viewedObject.parsonScripts;
        trace("--------parsons script--------");
        for (i = 0; i < scripts.length; i ++) trace(scripts[i].op);
        trace("---------");
		// current script on script pane
		var currScript:Array = viewedObject.scripts;
        trace("--------current script--------");
        for (i = 0; i < currScript.length; i ++) trace(currScript[i].op);
        trace("---------");

        //var prevScript:Array = viewedObject.prevScripts;
        //viewedObject.prevScripts = currScript;

        var sb:Block = scripts[0] as Block;
        var score:int = -10 * Number.MAX_VALUE;
        var maxStatus:int = -1;
        // var similarity:Number = calSimilarity(scripts, currScript);
        // trace("similarity: " + similarity);

        var parents: Array  = getParents(sb, null, viewedObject.recentBlock);

        // max score for correct answer at once
        
        var corrArr:Array = BlockIO.stackToArrayOnlySubstacks(sb);
        var correctCurr:int = 0;
        var lenCorrect:int = corrArr.length;
        var currMax:int = 0;
        for (i = 0; i < lenCorrect; i++) {
            currMax += corrArr[i].pointValue * lenCorrect;
        }
        maxScoreForGame = currMax;

        // calculate extra moves based on configurations of chunks
        var isEmpty:int = 0;
        for (var key:* in map){
            isEmpty++;
        }
        if (isEmpty == 0){
            meaningfulMoves = meaningfulMoves + 1;
        } else {
            var forceBreak:Boolean = false;
            for(i = 0; i < currScript.length; i++){
                var pb:Block = currScript[i] as Block;
                var pbArr:Array = BlockIO.stackToArrayOnlySubstacks(pb);
                var str:String = "";
                for(var j:int = 0; j < pbArr.length; j++){
                    str = str + pbArr[j].op;
                }
                if(map.hasOwnProperty(str)){
                    if(map[str]==1){
                        delete map[str];
                    } else {
                        map[str] = map[str] - 1;
                    }
                } else {
                    forceBreak = true;
                    break;
                }
            }
            if(forceBreak){
                meaningfulMoves = meaningfulMoves + 1;
            }
            for (var key:* in map){
                delete map[key];
            }
        }

        for (i = 0; i < currScript.length; i++){
            var pb:Block = currScript[i] as Block;
            var pbArr:Array = BlockIO.stackToArrayOnlySubstacks(pb);
            var str:String = "";
            for(var j:int = 0; j < pbArr.length; j++){
                str = str + pbArr[j].op;
            }
            if(map.hasOwnProperty(str)) {
                map[str] = map[str] + 1;
            } else {
                map[str] = 1;
            }
        }

        // calculate score
        for (i = 0; i < currScript.length; i++){
            trace(currScript[i].op);

            var pb:Block = currScript[i] as Block;

            var newParents: Array = getParents(pb, viewedObject.recentBlock.id, viewedObject.recentBlock);
            var curStatus:int = getStatusOfBlock(parents, newParents);

            if(curStatus > maxStatus){
                maxStatus = curStatus;
            }

            Logger.logAll("Final Status: " + maxStatus)

            var newScore:int = calculateScoreForChunk(sb, pb);

//            if(newScore > score){
//                score = newScore;
//            }
            if (newScore < 0) {
                newScore = 0
            }
            score += newScore
        }

        // static feedback
//        if(viewedObject.fromPalette && parents.length == 0) {
//            feedbackSignal = "Oops! You selected a distractor";
//        } else{
//            if (maxStatus == -1) {
//                feedbackSignal = "Keep going!";
//            } else if (maxStatus == 0){
//                feedbackSignal = "Oops! You might've missed a block";
//            } else if (maxStatus == 1){
//                feedbackSignal = "Nice job, keep going!";
//            } else {
//                feedbackSignal = "Correct move, great job!";
//            }
//        }

        var previousFeedback:String = feedbackSignal;
        if(viewedObject.fromPalette && parents.length == 0) {
            feedbackSignal = potentialFeedback[0];
            colorFlag = 4;
        } else {
            if (maxStatus == -1) {
                feedbackSignal = neutralFeedback[0];
                colorFlag = 2;
            } else if (maxStatus == 0) {
                feedbackSignal = incorrectFeedback[0];
                colorFlag = 1;
            } else if (maxStatus == 1) {
                feedbackSignal = correctFeedback[0];
                colorFlag = 3;
            } else {
                feedbackSignal = correctFeedback[0];
                colorFlag = 3;
            }
        }
//        if (previousFeedback != feedbackSignal) {
//            updateFlag += 1;
//        }
        updateFlag += 1;

        // add similarity rate
        // feedbackSignal = "Similarity: " + similarity + " " + feedbackSignal;
        trace("feedbackSignal " + feedbackSignal);
        stagePart.updateMessageLabel(feedbackSignal);
        // send feedback to the front end side
//        createSocket(8002);
//        var feedbackInfo:Object = {};
//        feedbackInfo.feedbackSignal = feedbackSignal;
//        client.writeUTFBytes(util.JSON.stringify(feedbackInfo));
//        client.flush();


        setPoints(score);
        // var d:DialogBox = new DialogBox(null);
        // d.addTitle("score");
        // d.addField('id', 50, score);
        // d.addButton('Cancel',null);
        // d.showOnStage(app.stage);


        // old implementations kept so that evaluation for feedback request works
        correct = true;
        notComplete = false;

        if(adding){
            totalMoves++;
        }

        var i:int;
        blocksCount=0;

        for (i = 0; i < currScript.length; i++){
            //current parson block
            var pb:Block = currScript[i] as Block;
            currPb = "pbIsNull";

            //saved block
            var sb:Block = scripts[i] as Block;
            correctSb = "sbIsNull";

            // end game when student reach correct answer
            var sbDict:Dictionary = new Dictionary();
            var dummySb:Block = sb;
            while(dummySb != null) {
                sbDict[dummySb.op] = true;
                if (dummySb.subStack1 != null) {
                    sbDict[dummySb.subStack1.op] = true;
                }
                if (dummySb.subStack2 != null) {
                    sbDict[dummySb.subStack2.op] = true;
                }
                dummySb = dummySb.nextBlock;
            }

            while(pb != null && sb!= null){
                prevBlock = correctSb;
                correctSb = sb.op;
                currPb = pb.op;

                if(pb.op == sb.op){

                    if(notComplete){
                        if(correct){
                            correct = false;
                            if (sbDict[pb.op] == null) {
                                //stagePart.updateMessageLabel("Oops! You selected a distractor");
                            }else{
                                //stagePart.updateMessageLabel("Oops! Wrong Choice");
                            }
                        }else{
                            //stagePart.updateMessageLabel("Try removing a few blocks!");
                            expectRemoval = true;
                        }
                    }else{
                        success = true;
                        checkSubstack(pb.subStack1, sb.subStack1);
                        checkSubstack(pb.subStack2, sb.subStack2);
                        if (!completed) {
                            //incrementPoints(pb.pointValue);
                        }
                        if(pb.subStack1 == null && pb.subStack2 == null && sb.subStack1 == null && sb.subStack2 == null){
                            if(correct){
                                //stagePart.updateMessageLabel("Good Going!");
                            }else{
                                //stagePart.updateMessageLabel("Try removing a few blocks!");
                                expectRemoval = true;
                            }
                        }
                    }
                }else{
                    if (sbDict[pb.op] == null) {
                        if(correct && !expectRemoval){
                            //stagePart.updateMessageLabel("Oops! You selected a distractor");
                        }else{
                            //stagePart.updateMessageLabel("Try removing a few blocks!");
                            expectRemoval = true;
                        }
                        if (!completed) {
                            //decrementPoints(pb.pointValue * 2);
                        }
                    } else {
                        if(correct && !expectRemoval){
                            //stagePart.updateMessageLabel("Oops! Wrong Choice");
                        }else{
                            //stagePart.updateMessageLabel("Try removing a few blocks!");
                            expectRemoval = true;
                        }
                        if (!completed) {
                            //decrementPoints(pb.pointValue);
                        }
                    }
                    correct = false;
                }
                sb = sb.nextBlock;
                blocksCount++;
                pb = pb.nextBlock;
            }

            while(pb != null){
                success = false;
                if (!completed) {
                    //decrementPoints(pb.pointValue);
                }
                //stagePart.updateMessageLabel("Try removing a few blocks!");
                expectRemoval = true;
                pb = pb.nextBlock;
            }

            if(sb != null){
                success = false;
                if(correct){
                    expectRemoval = false;
                }
            }

            evaluateForFeedbackRequest();
        }

        autoExecute();
        autoInitialize();

        // the points are only updated when the game is not completed yet and it's in the play mode
        if(!completed && interp.sagePlayMode) {
            setPoints(getPoints() - paletteBuilder.getPeerFeedbackCount() - 0); //(totalMoves - blocksCount)
            stagePart.updatePointsLabel();
            sendUpdatedPointsToServer();
            trace(getPoints());
        }

        // if the student reach the correct answer, submit automatically
        if(success && correct) {
            stagePart.updateMessageLabel("Congratulations!");
            if(!completed) {
                completed = true;
                summary();
                submitStudentGame();
            }
        }

        if (interp.studentParsonsMode) {
            paletteBuilder.showBlocksForCategory(Specs.parsonsCategory, false);
        }
    }

    public function calculateScoreForChunk(correct:Block, attempt:Block): int {
        var corrArr:Array = BlockIO.stackToArrayOnlySubstacks(correct);
        var attArr:Array = BlockIO.stackToArrayOnlySubstacks(attempt);
        var score:int = 0;
        var attemptCurr:int = 0;
        var attemptEnd:int = 0;
        var correctCurr:int = 0;
        var correctEnd:int = 0;
        var len:int = 0;
        if (corrArr) {
            var correctUsed:Array = new Array(corrArr.length);
            for each(var v:Boolean in correctUsed) {
                v = false;
            }
        }

        try {
            while (attemptCurr < attArr.length) {
                correctCurr = 0;
                var maxLen:int = -1;
                var maxIdx:int = 0;
                var maxScoreForSeq:int = 0;
                var nxtAttempt:int = 0;
                while (correctCurr < corrArr.length) {
                    if (correctUsed[correctCurr]) {
                        correctCurr++;
                        continue;
                    }

                    if (attArr[attemptCurr].op == corrArr[correctCurr].op) {
                        attemptEnd = attemptCurr;
                        correctEnd = correctCurr;
                        var distance:int = Math.abs(correctCurr - attemptCurr);
                        while (attemptEnd < attArr.length && correctEnd < corrArr.length && attArr[attemptEnd].op == corrArr[correctEnd].op) {
                            attemptEnd += 1;
                            correctEnd += 1;
                        }
                        len = attemptEnd - attemptCurr;
                        if (len > maxLen) {
                            maxLen = len;
                            maxIdx = correctCurr;
                            var localScore:int = 0;
                            var sequenceScore:int = 0;
                            for (var i:int = attemptCurr; i < attemptEnd; i++) {
                                localScore += len * attArr[i].pointValue;
                                sequenceScore += attArr[i].pointValue;
                            }
                            var sequenceAvg:Number = sequenceScore / len;
                            localScore -= sequenceAvg * distance;
                            maxScoreForSeq = localScore;
                            nxtAttempt = attemptEnd - 1;
                        }
                    }
                    correctCurr += 1;
                }

                if (maxLen != -1) {
                    for (var i:int = 0; i < maxLen; i++) {
                        correctUsed[maxIdx + i] = true;
                    }
                    attemptCurr = nxtAttempt;
                    score += maxScoreForSeq
                } else {
                    score -= attArr[attemptCurr].pointValue;
                }

                attemptCurr += 1;
            }
        } catch (err) {
            trace(err);
        }
        return score;// - meaningfulMoves;
    }

//    public function calculateScoreForChunk(correct:Block, attempt:Block): int {
//        var corrArr:Array = BlockIO.stackToArrayOnlySubstacks(correct);
//        var attArr:Array = BlockIO.stackToArrayOnlySubstacks(attempt);
//
//
//        var matches:int = 0;
//        var counter:int = 0;
//        var score:Number = -10 * Number.MAX_VALUE;
//
//        while(attArr != null && matches < attArr.length){
//
//            counter = 0;
//            while(corrArr != null && counter < corrArr.length){
//
//                if(corrArr[counter].op == attArr[matches].op){
//
//                    Logger.logAll("found a match");
//                    Logger.logAll(attArr[matches].op);
//
//                    var nulls:int = counter - matches;
//                    var toCompare:Array = [];
//
//                    while(nulls > 0){
//                        Logger.logAll("nulls");
//                        Logger.logAll("" + nulls);
//                        toCompare.unshift(null);
//                        nulls -= 1;
//                    }
//
//                    toCompare = toCompare.concat(attArr);
//
//                    var newScore:int = manhattanDistance(corrArr, toCompare);
//                    Logger.logAll("new segment score:" + newScore + "previous max:" + score)
//
//                    if(newScore > score){
//                        score = newScore;
//                        //Logger.logAll("score u:" + score);
//                    }
//                }
//
//                counter += 1;
//
//            }
//
//            matches += 1
//
//        }
//
//        var toAdd:int = 0;
//        for each(var item:Block in corrArr){
//            toAdd += (item.pointValue * corrArr.length);
//        }
//
//        Logger.logAll("offset Added:" + toAdd);
//        return score + toAdd;
//
//    }

    public function manhattanDistance(correct:Array, attempt:Array): int{
        var score1:int = 0;
        var count:int  = 0;
        while(count < correct.length && count < attempt.length){
            if(attempt[count] == null || (correct[count].op != attempt[count].op)){
                if(attempt[count] == null ){
                    Logger.logAll("comparing " + correct[count].op + " and " + attempt[count]);
                }else{
                    Logger.logAll("comparing " + correct[count].op + " and " + attempt[count].op);
                }

                var distance:int  = 0;
                var found:Boolean = false;

                //search down
                while(count + distance + 1 < attempt.length && !found){
                    distance += 1;
                    if(attempt[count + distance] != null && correct[count].op == attempt[count + distance].op){
                        found = true;
                    }
                }

                if(!found){
                    distance = 0;
                }
                //search up
                while(count - distance - 1 > 0 && !found){
                    distance += 1;
                    if(attempt[count - distance] != null && correct[count].op == attempt[count - distance].op){
                        found = true;
                    }
                }

                if(found){
                    Logger.logAll("Found correct line inside solution " + distance + " blocks away");
                    score1 -= (correct[count].pointValue * distance);
                }else{
                    Logger.logAll("Correct line not found in solution");
                    score1 -= (correct[count].pointValue * correct.length);
                }

            }else{
                Logger.logAll("comparing " + correct[count].op + " and " + attempt[count].op);
            }

            count += 1;
        }

        //student solution longer than model solution
        //decrement 1 point for every extra block
        while(count < attempt.length){
            score1 -= 1;
            count += 1;
        }


        //student solution shorter than instructor's
        while(count < correct.length){

            found = false;
            distance = 0
            while(count - distance - 1 > 0 && !found){
                distance += 1;
                if(attempt[count - distance] != null && correct[count].op == attempt[count - distance].op){
                    found = true;
                }
            }

            if(found){
                Logger.logAll("Found correct line inside solution " + distance + " blocks away");
                score1 -= (correct[count].pointValue * distance);
            }else{
                Logger.logAll("Correct line not found in solution");
                score1 -= (correct[count].pointValue * correct.length);
            }

            count += 1;
        }

        return score1
    }

    public function autoExecute(): void{
        //auto-execution
        runtime.startGreenFlags(true);
    }

    public function autoInitialize(): void{
        //auto-initialization
        if(!interp.sageDesignMode){
            for each (var scratchObj:ScratchSprite in stagePane.sprites()) {
                scratchObj.setInitSprite();
            }
        }
        else{
            for each (var scratchObj:ScratchSprite in stagePane.sprites()) {
                scratchObj.setInitXY(scratchObj.scratchX, scratchObj.scratchY, scratchObj.direction, scratchObj.rotationStyle);
                scratchObj.setInitSprite();
            }
        }
    }

    // for loop
    public function checkSubstack(block1:Block, block2:Block):void{
        while(block1 != null && block2 != null){
            prevBlock = correctSb;
            correctSb = block2.op;
            currPb = block1.op;

            if(block1.op == block2.op){
                success=true;
                blocksCount++;
                checkSubstack(block1.subStack1, block2.subStack1);
                checkSubstack(block1.subStack2, block2.subStack2);
                incrementPoints(block1.pointValue);
                if(correct){
                    //stagePart.updateMessageLabel("Good Going!");
                }else{
                    //stagePart.updateMessageLabel("Try removing a few blocks!");
                    expectRemoval = true;
                }
            }else{
                success = false;
                decrementPoints(block1.pointValue);
                if(correct && !expectRemoval){
                    //stagePart.updateMessageLabel("Oops! Wrong Choice");
                }else{
                    //stagePart.updateMessageLabel("Try removing a few blocks!");
                    expectRemoval = true;
                }
                correct = false;
            }

            block1 = block1.nextBlock;
            block2 = block2.nextBlock;
        }

        while(block1 != null){
            success = false;
            decrementPoints(block1.pointValue);
            //stagePart.updateMessageLabel("Try removing few blocks!");
            expectRemoval = true;
            block1 = block1.nextBlock;
        }

        if(block2 != null){
            success = false;
            if(correct){
                expectRemoval = false;
            }
            notComplete = true;
        }
    }

    public function evaluateForFeedbackRequest(): void{
        if(!correct){
            getFeedback = false;
            firstWrongState = !wrongState;
            wrongState = true;
            wrongBlock = currPb;
            correctBlock = correctSb;
            expectDummyCheck = true;
        }else if (firstWrongState && !expectDummyCheck){
            //if all is correct and they were wrong before
            getFeedback = true;
            wrongState = firstWrongState = false;
        }else if (firstWrongState && expectDummyCheck){
            // automatic check when student drags off wrong block
            expectDummyCheck = false;
        }else if(!expectDummyCheck){
            //everything is correct, reset so student can submit exp in the future
            expectDummyCheck = false;
            getFeedback = false;
            wrongState = firstWrongState = false;
        }else if(expectDummyCheck){
            expectDummyCheck = false;
        }
    }

    public function summary():void {
        function ok():void {
        }
        var d:DialogBox = new DialogBox(null);
        if(success){
            d.addTitle('Congratulations!');
            d.addText(submitMsg);
        }else{
            d.addTitle('Better Luck Next Time!');
            d.addText('You were very close...');
        }

        d.addText('Your score: ' + getPoints());
        d.addText('Correct Moves: ' + blocksCount);
        // d.addText('Incorrect Moves: ' + (totalMoves - blocksCount));
        d.addText('Meaningful Moves: ' + meaningfulMoves);
        d.addText('Hint Used: ' + paletteBuilder.getHintCount());
        d.addButton('Ok', ok);
        d.showOnStage(app.stage);
    }

    public function getSelfExplanation():void {
        function ok():void {
            selfExplanation = d.getField("Enter Explanation");
            summary();
            submitStudentGame();
        }

        var d:DialogBox = new DialogBox(null);
        d.addTitle('Self-Explanation');
//		d.addTextArea('Enter Explanation', 300, 200, comments);
        d.addField('Enter Explanation', 500, selfExplanation);
        d.addButton('Ok', ok);
        d.addButton('Cancel',null);
        d.showOnStage(app.stage);
    }

    public var sagePalettesDefault:Array = [
        false, // placeholder
        true, true, true, true, true, // column 1
        true, true, true, true, true]; // column 2

    // construct function
    public function Scratch() {
        loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, uncaughtErrorHandler);
        app = this;
        trace("game loaded");
        // This one must finish before most other queries can start, so do it separately
        determineJSAccess();
    }

    function onFileLoaded(event:Event):void {
        trace("onfileloaded called");
        var fileReference:FileReference = event.target as FileReference;

        // These steps below are to pass the data as DisplayObject
        // These steps below are specific to this example.
        var data:ByteArray = fileReference["data"];
        var lol:Object = util.JSON.parse(data.readUTF());
        Specs.pointDict = lol;
        trace(lol);
    }

    private function mouseClickListener(e:MouseEvent=null):void{
        gh.mouseUp(e);
        // TODO: remove mock params
        // this.postJson(stagePane, 'stu123', 'game123', 'obj123');
        if (this.queryParams != null && this.sid != null && this.assignmentID != null && this.mode != null && this.objectiveID!= null) {
            this.postJson(stagePane, sid, assignmentID, objectiveID);
        }
        if(this.doSave==false){
            // Logger.logAll("auto saving");
            this.doSave=true;
            var projIO:ProjectIO = new ProjectIO(this);
            var zipData:ByteArray = projIO.encodeProjectAsZipFile(stagePane);
            this.uploadToServer(zipData);
            this.doSave=false;
        }
}

    // initialize
	protected function initialize():void {

		trace("editor initializing");

		// isOffline = loaderInfo.url.indexOf('http:') == -1;
		// forcing isOffline to be true, because it would stopping stage from being populated in embedded mode
		isOffline = true;
		checkFlashVersion();

		initServer();

		stage.align = StageAlign.TOP_LEFT;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.frameRate = 30;

		Block.setFonts(10, 9, true, 0); // default font sizes
		Block.MenuHandlerFunction = BlockMenus.BlockMenuHandler;
		CursorTool.init(this);
		app = this;

		stagePane = new ScratchStage();
		gh = new GestureHandler(this, (loaderInfo.parameters['inIE'] == 'true'));
		initInterpreter();
		initRuntime();
		initExtensionManager();
		Translator.initializeLanguageList();

		playerBG = new Shape(); // create, but don't add
		addParts();

		stage.addEventListener(MouseEvent.MOUSE_DOWN, gh.mouseDown);
		stage.addEventListener(MouseEvent.MOUSE_MOVE, gh.mouseMove);
		stage.addEventListener(MouseEvent.MOUSE_UP, this.mouseClickListener);
		stage.addEventListener(MouseEvent.MOUSE_WHEEL, gh.mouseWheel);
		stage.addEventListener('rightClick', gh.rightMouseClick);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, runtime.keyDown);
		stage.addEventListener(KeyboardEvent.KEY_UP, runtime.keyUp);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDown); // to handle escape key
		stage.addEventListener(Event.ENTER_FRAME, step);
		stage.addEventListener(Event.RESIZE, onResize);

		setEditMode(startInEditMode());

		// install project before calling fixLayout()
		if (editMode) runtime.installNewProject();
		else runtime.installEmptyProject();

		fixLayout();

		//  LOADING GAME DATA
        //  This part is created by SAGE

        this.queryParams = this.root.loaderInfo.parameters;
        this.sid = LoaderInfo(this.root.loaderInfo).parameters.sid;
        this.assignmentID = LoaderInfo(this.root.loaderInfo).parameters.assignmentID;
		this.objectiveID =  LoaderInfo(this.root.loaderInfo).parameters.objectiveID;
        this.mode = LoaderInfo(this.root.loaderInfo).parameters.mode==undefined?"DESIGN":LoaderInfo(this.root.loaderInfo).parameters.mode;
        this.baseUrl = LoaderInfo(this.root.loaderInfo).parameters.backend;
		// this.baseUrl = 'http://localhost:8081'
		this.gameType = LoaderInfo(this.root.loaderInfo).parameters.type;

        try {
            var url:String = ExternalInterface.call("window.location.href.toString");
            var splitURL:Array = url.split("/");
            if (url) Logger.logBrowser("******URL: " + url);
            if (this.sid == "{{sid}}" || this.sid == "{{studentID}}" || this.sid == null) {
                this.sid = splitURL[splitURL.length - 1].split("?")[0];
            }
            if (this.assignmentID == "{{assignmentID}}" || this.assignmentID == null) {
                this.assignmentID = splitURL[splitURL.length - 2];
            }
            if (this.baseUrl == null) {
                this.baseUrl = url.indexOf("http://") == 0 ? url.substring(0,url.indexOf("/", 7))
                                                            : url.substring(0, url.indexOf("/"));
            }
        } catch (error:Error) {
            this.baseUrl="http://localhost:8081";
            this.sid = '5db383c977376c28c4eb0614';
            // free mode
            this.assignmentID = '5deb14f4f701653550e4773b';
            // normal mode
           // this.assignmentID = '5db4ed770857c75ac46c588d';
        }

        // hard coded test
//        this.baseUrl="http://localhost:8081";
//        this.sid = '5db383c977376c28c4eb0614';
//        // free mode
//        this.assignmentID = '5de57fd132f3784f40d11d65';
//        // normal mode
 //      this.assignmentID = '5db4ed770857c75ac46c588d';

		// more parameters can be added as and when required
        //		if (this.queryParams != null && this.sid != null && this.assignmentID != null && this.mode != null && this.objectiveID!= null) {
        //            startTimer(sid, assignmentID,this.objectiveID);
        //        }
        Logger.logBrowser("mode: " + this.mode);
		if (this.mode != "DESIGN") {
            toggleSagePlayMode();
		}

        this.startTime = new Date().valueOf().toString();
        createSocket();

        Logger.logBrowser("game id: " + this.assignmentID);
        Logger.logBrowser("user id: " + this.sid);
        Logger.logBrowser("game mode : "+this.mode);
		Logger.logBrowser("backend url is "+this.baseUrl);
        Logger.logBrowser("game type is " + this.gameType);
        interp.gameType = this.gameType;

        try{
            if(ExternalInterface.available) {
                var location:String = ExternalInterface.call("window.location.href.toString");
                if (location.indexOf("instructor") >= 0) {
                    interp.isStudent = false;
                }
            }
        } catch(e:Error) {

        }

        Logger.logBrowser("====== interp.gameType: " + interp.gameType);
        Logger.logBrowser("====== interp.isStudent: " + interp.isStudent);

		// load relevant variables for hinting from Dashboard
		var h:Hints = new Hints();
		this.addChild(h);
		// TODO: need to fix launch errors and uncomment
		// h.getRulesFile();

		if (this.assignmentID) {
			Logger.logBrowser("getting saved data");
			this.getSavedData(this.assignmentID);
            this.getAssignmentMoveFeedback(this.assignmentID);
		} else {
			trace("no objectiveId present");
		}

        stagePart.refresh();
        viewedObject.updateScriptsAfterTranslation();
	}

    public function createSocket(port:int=8001):void {
        if (this.baseUrl == null) {
            // trace("empty baseURL, not creating socket");
            Logger.logBrowser("empty baseURL, not creating socket");
            return;
        }

        var hostnameArray:Array = this.baseUrl.split(":");
        var hostname:String = hostnameArray.length == 1 ? this.baseUrl : hostnameArray.join(":");
        if (hostname.indexOf("http://") == 0) {
            hostname = hostname.substring(7, hostname.length).split(":")[0];
        }
        Logger.logBrowser("Hostname is: " + hostname);

        try {
            Logger.logBrowser("Fetching policy file from: " + "xmlsocket://" + hostname + ":8888");
            Security.loadPolicyFile("xmlsocket://" + hostname + ":8888");
        } catch (error: Error) {
            Logger.logBrowser("Fetching policy file failed: " + error.message);
        }


        client = new Socket();

        function onIOErrorFailed(e:Event):void {
            trace("Socket connection failed. Make sure the server is up." + e.toString());
            Logger.logBrowser("Socket connection failed. Encounter IOError." + e.toString());
        }

        function onSecurityErrorFailed(e:Event):void {
            trace("Socket connection failed. Make sure the server is up." + e.toString());
            Logger.logBrowser("Socket connection failed. Encounter SecurityError." + e.toString());
        }

        function onUncaughtErrorFailed(e:Event):void {
            trace("Socket connection failed. Make sure the server is up." + e.toString());
            Logger.logBrowser("Socket connection failed. Encounter UncaughtError." + e.toString());
        }

        client.addEventListener(IOErrorEvent.IO_ERROR, onIOErrorFailed);
        client.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityErrorFailed);
        client.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtErrorFailed);

        function closeHandler():void {
            socketIsConnected = false;
            Logger.logBrowser("Socket connection is closed.");
            trace("socket closed");
        }

        function connectHandler():void {
            Logger.logBrowser("Socket connected successfully.");
            Logger.logBrowser("Socket connection status: " + client.connected.toString());
            socketIsConnected = true;
            var socketSignature: Object = {};
            socketSignature.event = "SOCKET_SIGNATURE";
            socketSignature.assignmentID = assignmentID;
            socketSignature.id = sid;
            socketSignature.timestamp = new Date().valueOf().toString();
            var stringPayload:String = util.JSON.stringify(socketSignature);
            try {
                client.writeUTFBytes(util.JSON.stringify(socketSignature));
                Logger.logBrowser(stringPayload.slice(1, stringPayload.length-1).split("\n").join(""));
                client.flush();
                trace("socket connected, sent signature");
            } catch (e) {
                trace("socket error " + e.toString());
            }


        }

        function dataHandler():void {
            var socketData:String = client.readUTFBytes(client.bytesAvailable);
            try {
                var parsedSocketData:Object = util.JSON.parse(socketData);
                if (parsedSocketData.event == null) {
                    trace("Invalid socket data: event undefined");
                    return;
                }
                trace(parsedSocketData.toString());
                switch (parsedSocketData.event) {
                    case "SUBMISSION": {
                        selfExplanation = parsedSocketData.selfExplanation;
						Logger.logBrowser("Receive SUBMISSION event from server.");
						submitStudentGame();
						//Logger.logBrowser(fixFileName(defaultName));
                        
                        break;
                    }
                    case "HINTUSAGE": {
                        paletteBuilder.incrementHintCounter();
                        Logger.logBrowser("Receive HINTUSAGE event from server. Hint count is " + paletteBuilder.getHintCount().toString());
                        app.decrementPoints(1);
                        Logger.logBrowser("The point is now: " + app.getPoints().toString());
                        sendUpdatedPointsToServer();
                        break;
                    }
                    case "PEER_FEEDBACK_REQUESTED": {
                        paletteBuilder.incrementPeerFeedbackCounter();
                        Logger.logBrowser("Received PEER_FEEDBACK_REQUESTED event from server.");
                        app.decrementPoints(1);
                        Logger.logBrowser("The point is now: " + app.getPoints().toString());
                        sendUpdatedPointsToServer();
                        break;
                    }
                    case "CHECKDUPLICATE": {
                        hasDuplicateResponse.isDuplicate = parsedSocketData.isDuplicate;
                        Logger.logBrowser("Receive CHECKDUPLICATE event from server.");
                        break;
                    }
                    case "RETURN_POINT_CONFIG": {
                        hasConfigResponse.configList = parsedSocketData.configList;
                        Logger.logBrowser("Receive RETURN_POINT_CONFIG event from server.");
                        break;
                    }
                    default:
                        trace("Unrecognized event: " + parsedSocketData.event);
                        Logger.logBrowser("Unrecognized event:" + parsedSocketData.event);
                        Logger.logBrowser("Unrecognized event: The payload is: " + socketData);
                }
            } catch (errString: String) {
                trace("Invalid JSON String" + errString);
                Logger.logBrowser("Socket parse data error: The payload is: " + socketData);
            }
        }

        client.addEventListener(Event.CLOSE, closeHandler);
        client.addEventListener(Event.CONNECT, connectHandler);
        client.addEventListener(ProgressEvent.SOCKET_DATA, dataHandler);

        function connect():void {
            if( !socketIsConnected ){
                try {
                    Logger.logBrowser("Trying to reconnect socket.");
                    client.connect(hostname, 8001);
                } catch(ioError: IOError) {
                    Logger.logBrowser("Socket connection failed: " + ioError.message);
                } catch(secError: SecurityError) {
                    Logger.logBrowser("Socket connection failed: " + secError.message);
                }
            }
        }

        try {
            client.connect(hostname, port);
        } catch(ioError: IOError) {
            Logger.logBrowser("Socket initial connection failed: " + ioError.message);
        } catch(secError: SecurityError) {
            Logger.logBrowser("Socket initial connection failed: " + secError.message);
        }

        var connectTimer:Timer = new Timer( 1000 );
        connectTimer.addEventListener(TimerEvent.TIMER, connect);
        connectTimer.start();
    }

	private function getSavedData(oid:String):void{
		var url:String = this.baseUrl+"/games/get/"+oid;
		var notFound:Boolean = false;
		var savedDataRequest:URLRequest = new URLRequest(url);
        savedDataRequest.method = URLRequestMethod.GET;
		var loader:URLLoader = new URLLoader();
		Logger.logAll("getting saved data "+url);
		function onComplete(e:Event):void{
			Logger.logAll("get game complete");
			loader.close();
			try{
				if(!notFound){
                    runtime.installProjectFromFile(oid,loader.data);
					Logger.logBrowser("game populated");
				}
			}catch (error:Error) {
				Logger.logAll("can not install save data"+ error);
            }

		}
		function onFailed(e:Event):void{
			Logger.logAll("can not get resource");
		}
		function onHttpResponse(status:HTTPStatusEvent):void{
			if(status.status == 404){
				notFound = true;
			}
		}
		loader.dataFormat = URLLoaderDataFormat.BINARY;
		loader.addEventListener(Event.COMPLETE,onComplete);
		loader.addEventListener(IOErrorEvent.IO_ERROR, onFailed);
		loader.addEventListener(HTTPStatusEvent.HTTP_STATUS,onHttpResponse);
		try{
			loader.load(savedDataRequest);
		}catch (error:Error){
			Logger.logAll("error happened"+ error.message)
		}
	}

    private function getAssignmentMoveFeedback(oid:String):void{
        var url:String = this.baseUrl+"/assignment/"+oid+"/getmovefeedback";
        var notFound:Boolean = false;
        var savedDataRequest:URLRequest = new URLRequest(url);
        savedDataRequest.method = URLRequestMethod.GET;
        var loader:URLLoader = new URLLoader();
        Logger.logAll("getting move feedback "+url);
        function onComplete(e:Event):void{
            Logger.logAll("get feedback complete");
            loader.close();
            try{
                if(!notFound){
                    trace("feedback");
                    var feedbackArr:Array = util.JSON.parse(loader.data.toString())["moveFeedbacks"];
                    trace(feedbackArr);
                    for each (var feedback:Object in feedbackArr) {
                        // trace(feedback["type"]);
                        if (feedback["type"] == "correct") {
                            correctFeedback.push(feedback["content"]);
                        } else if (feedback["type"] == "incorrect") {
                            incorrectFeedback.push(feedback["content"]);
                        } else if (feedback["type"] == "neutral") {
                            neutralFeedback.push(feedback["content"]);
                        } else {
                            potentialFeedback.push(feedback["content"]);
                        }
                    }

                    if (correctFeedback.length == 0) {
                        correctFeedback.push("Correct move, great job!");
                    }
                    if (incorrectFeedback.length == 0) {
                        incorrectFeedback.push("Oops! That might be the wrong spot.");
                    }
                    if (neutralFeedback.length == 0) {
                        neutralFeedback.push("Keep going!");
                    }
                    if (potentialFeedback.length == 0) {
                        potentialFeedback.push("Oops! You selected a distractor");
                    }

//                    trace("=====feedback=====");
//                    trace(correctFeedback[0]);
//                    trace(incorrectFeedback[0]);
//                    trace(neutralFeedback[0]);
//                    trace(potentialFeedback[0]);

                    var gameType:String = util.JSON.parse(loader.data.toString())["type"];
                    Logger.logBrowser("Game Type: " + gameType);
                    if (gameType.indexOf("feedback") >= 0) {
                        Logger.logBrowser("activate free mode");
                        interp.freeMode = true;
                        interp.preciseMode = false;
                        interp.studentParsonsMode = false;
                        stagePart.refresh();
                    }
                    if (gameType.indexOf("cvg") >= 0) {
                        Logger.logBrowser("cvg mode");
                        interp.isCvg = true;
                        stagePart.refresh();
                    }
                }
            }catch (error:Error) {
                Logger.logAll("can not load feedback");
            }

        }
        function onFailed(e:Event):void{
            Logger.logAll("can not get resource");
        }
        function onHttpResponse(status:HTTPStatusEvent):void{
            if(status.status == 404){
                notFound = true;
            }
        }
        loader.dataFormat = URLLoaderDataFormat.BINARY;
        loader.addEventListener(Event.COMPLETE,onComplete);
        loader.addEventListener(IOErrorEvent.IO_ERROR, onFailed);
        loader.addEventListener(HTTPStatusEvent.HTTP_STATUS,onHttpResponse);
        try{
            loader.load(savedDataRequest);
        }catch (error:Error){
            Logger.logAll("error happened"+ error.message)
        }
    }

	private function showIds(queryParams:String, sid:String, assignmentID:String, objectiveID:String, mode:String):void{
        var d:DialogBox = new DialogBox();
		d.addText(queryParams);
		d.addText(sid);
        d.addText("wow awesome cool");
		d.addText(assignmentID);
		d.addText(objectiveID);
		d.addText(mode);
		d.showOnStage(stage);
	}

	private function getIds():void {
		function cancel():void {
			d.cancel();
		}

		function ok():void {
			var sid:String = d.getField("Student ID");
			var aid:String = d.getField("Assignment ID");
			//default play mode for students
			toggleSagePlayMode();
			// sm4241: Most probably its polling timer
            // TODO: Remove startTimer.
			// startTimer(sid, aid, '');
		}

		var d:DialogBox = new DialogBox();
		d.addTitle("Welcome to SAGE!");
		d.addField("Student ID", 100, "", true);
		d.addField("Assignment ID", 100, "", true);
		d.addButton('Ok', ok);
		d.addButton('Cancel', cancel);
		d.showOnStage(stage);
	}


	// TODO: Remove this because we no longer postJson every second.
    //	private function startTimer(sid:String, aid:String, oid:String):void {
    //		var tick:int = 0;
    //        function timerPop(e:TimerEvent):void {
    //			postJson(stagePane, sid, aid,oid);
    //		}
    //
    //		var myTimer:Timer = new Timer(1000);
    //		myTimer.start();
    //		myTimer.addEventListener(TimerEvent.TIMER, timerPop);
    //	}

	private function postJson(proj:*, sid:String, aid:String, oid:String):void {
		// submitProject();
		// Sending JSON project via HTTP POST
        // var baseUrl:String = "http://localhost:8081";
		// TODO: move baseUrl to class level, assign the value in init function
        // var baseUrl:String = "http://dev.cu-sage.org:8081";
        var baseUrl:String = this.baseUrl;
		// create dynamic url
        //        var request:URLRequest = new URLRequest(baseUrl+"/games/student/"+sid+"/game/"+aid+"/objective/5g8d845736e4ddb3ce20ed1b3")
		var request:URLRequest = new URLRequest(baseUrl+"/games/student/"+sid+"/game/"+aid+"/objective/"+oid);

		var loader:URLLoader = new URLLoader();
		loader.dataFormat = URLLoaderDataFormat.TEXT;
		request.method = URLRequestMethod.POST;

		// assign the data to be sent by POST
		request.data = util.JSON.stringify(proj);
		request.contentType = "text/plain";

		function onPostComplete(e:Event):void {
            getAssessmentResults(sid, aid, oid);
            try {
                const hintsInfo:Object = util.JSON.parse(e.target.data);
                processHints(hintsInfo);
            }
            catch(error:*){
                Logger.logAll("Failed processing hints: " + error);
            }
		}

		function onPostError(e:IOErrorEvent):void {
            Logger.logAll("Error posting the assignment: " + e.toString());
		}

		loader.addEventListener(Event.COMPLETE, onPostComplete);
		loader.addEventListener(IOErrorEvent.IO_ERROR, onPostError);

		// send the request
		loader.load(request);



		var now:Date = new Date();
		var time:String = now.toString();
		var output_pathname:String = time + ".json";
		output_pathname = output_pathname.replace(/\s+/g, "-");
		output_pathname = output_pathname.replace(/:/g, "-");
		var jsonString:String = util.JSON.stringify(proj);
		// var fileRef:FileReference = new FileReference();
		// fileRef.save(jsonString, output_pathname);

		var so:SharedObject = SharedObject.getLocal(output_pathname, "/");
		so.data.json = jsonString;
		so.flush();
	}

    /*
    * Processes the hints information.
    * yli Nov, 2018
    */
    private function processHints(hintsInfo:*):void {
        if (hintsInfo && hintsInfo.hints) {
            Logger.logAll("Processing Hints: " + hintsInfo.hints);
            Logger.logAll("Next automatic hinting time: " + hintsInfo.nextAutoHintTime);
            var nextAutoHintTime:Date = null;
            if (hintsInfo.nextAutoHintTime) {
                nextAutoHintTime = new Date(hintsInfo.nextAutoHintTime);
            }
            palette.updateHints(hintsInfo.hints, nextAutoHintTime);
        }
        else {
            palette.updateHints([], null);
            Logger.logAll("Error getting hints: incorrect hints info " + hintsInfo);
        }
    }

    public function storeUpdatedGameSetting():void {
        var payload:Object = {};
        payload.event = "UPDATE_GAME_SETTING";
        payload.assignmentID = assignmentID;
        payload.id = sid;
        payload.time = paletteBuilder.getInputTimeInSeconds().toString();
        payload.question = paletteBuilder.getQuestion();
        payload.hint = paletteBuilder.getHint();
        payload.basic = cutoff1.toString();
        payload.developing = cutoff2.toString();
        payload.proficient = maxScore.toString();
        payload.submitMsg = submitMsg;

        var stringPayload:String = util.JSON.stringify(payload);
        try {
            client.writeUTFBytes(stringPayload);
            Logger.logBrowser(stringPayload.slice(1, stringPayload.length-1).split("\n").join(" "));        trace("Trying to store updated game setting: " + util.JSON.stringify(payload));
            client.flush();
            trace("Trying to store updated game setting: " + util.JSON.stringify(payload));
        } catch (e) {
            trace("socket error " + e.toString());
        }

    }

    private function getAssessmentResults(sid:String, aid:String, oid:String):void {
        //	var request:URLRequest = new URLRequest("http://sage-2ik12mb0.cloudapp.net:8081/students/"+sid+"/assessments/"+aid+"/results");

        //	var request:URLRequest = new URLRequest("http://localhost:8081/students/"+sid+"/assessments/"+aid+"/results");
        //        var request:URLRequest = new URLRequest("http://dev.cu-sage.org:8081/assess/game/"+aid+"/objective/58d845736e4ddb3ce20ed1b3");
		var request:URLRequest = new URLRequest(this.baseUrl+"/assess/game/"+aid+"/objective/"+oid+"/student/"+sid);

		var loader:URLLoader = new URLLoader();

		request.method = URLRequestMethod.GET;

		function onGetComplete(e:Event):void {
			trace("Successfully got the assessment results: " + loader.data);

			var results:Object = util.JSON.parse(e.target.data);
			processAssessmentResults(results);
		}

		function onGetError(e:Event):void {
			trace("Error getting the assignment results: " + e.toString());
		}

		loader.addEventListener(Event.COMPLETE, onGetComplete);
		loader.addEventListener(IOErrorEvent.IO_ERROR, onGetError);

		trace("Getting assessment results: " + request);

		// send the request
		loader.load(request);
	}

	private function processAssessmentResults(results:*):void {
		for(var i:int = 0; i < results.length; i++) {
			var result:* = results[i];

			if (result.actions != null) {
				for (var j:int = 0; j < result.actions.length; j++) {
					var action:* = result.actions[j];

					if (action.type == "action_block_include") {
						paletteBuilder.updateBlock(action.command, true);
					}

					if (action.type == "action_block_exclude") {
						paletteBuilder.updateBlock(action.command, false);
					}
				}
			}
		}
	}

	protected function initTopBarPart():void {
		topBarPart = new TopBarPart(this);
	}

	protected function initInterpreter():void {
		interp = new Interpreter(this);
	}

	protected function initRuntime():void {
		runtime = new ScratchRuntime(this, interp);
	}

	protected function initExtensionManager():void {
		extensionManager = new ExtensionManager(this);
	}

	protected function initServer():void {
		server = new Server();
	}

	protected function setupExternalInterface(oldWebsitePlayer:Boolean):void {
		if (!jsEnabled) return;

		addExternalCallback('ASloadExtension', extensionManager.loadRawExtension);
		addExternalCallback('ASextensionCallDone', extensionManager.callCompleted);
		addExternalCallback('ASextensionReporterDone', extensionManager.reporterCompleted);
	}

	public function showTip(tipName:String):void {}
	public function closeTips():void {}
	public function reopenTips():void {}
	public function tipsWidth():int { return 0; }
	public function getViewedObject():ScratchObj { return viewedObject; }
	public function getStage():StagePart { return stagePart; }

	protected function startInEditMode():Boolean {
		return true;
	}

	public function getMediaLibrary(type:String, whenDone:Function):MediaLibrary {
		return new MediaLibrary(this, type, whenDone);
	}

	public function getMediaPane(app:Scratch, type:String):MediaPane {
		return new MediaPane(app, type);
	}

	public function getScratchStage():ScratchStage {
		return new ScratchStage();
	}

	public function getPaletteBuilder():PaletteBuilder {
		//return new PaletteBuilder(this);
		// SAGE uses a persistent palatteBuilder to store block includes/excludes
		if(!paletteBuilder) {
			paletteBuilder = new PaletteBuilder(this);
			return paletteBuilder;
		}
		else
			return paletteBuilder;
	}

	private function uncaughtErrorHandler(event:UncaughtErrorEvent):void {
		if (event.error is Error)
		{
			var error:Error = event.error as Error;
			logException(error);
		}
		else if (event.error is ErrorEvent)
		{
			var errorEvent:ErrorEvent = event.error as ErrorEvent;
			Logger.logAll("uncaughtErrorHandler:" + errorEvent.toString());
		}
	}

	public function log(s:String):void {
		trace(s);
	}

	public function logException(e:Error):void {}
	public function logMessage(msg:String, extra_data:Object=null):void{
        trace(msg);
    }
	public function loadProjectFailed():void {}

	protected function checkFlashVersion():void {
		SCRATCH::allow3d {
			if (Capabilities.playerType != "Desktop" || Capabilities.version.indexOf('IOS') === 0) {
				var versionString:String = Capabilities.version.substr(Capabilities.version.indexOf(' ') + 1);
				var versionParts:Array = versionString.split(',');
				var majorVersion:int = parseInt(versionParts[0]);
				var minorVersion:int = parseInt(versionParts[1]);
				if ((majorVersion > 11 || (majorVersion == 11 && minorVersion >= 7)) && !isArmCPU && Capabilities.cpuArchitecture == 'x86') {
					render3D = (new DisplayObjectContainerIn3D() as IRenderIn3D);
					render3D.setStatusCallback(handleRenderCallback);
					return;
				}
			}
		}

		render3D = null;
	}

	SCRATCH::allow3d
	protected function handleRenderCallback(enabled:Boolean):void {
		if(!enabled) {
			go2D();
			render3D = null;
		}
		else {
			for(var i:int=0; i<stagePane.numChildren; ++i) {
				var spr:ScratchSprite = (stagePane.getChildAt(i) as ScratchSprite);
				if(spr) {
					spr.clearCachedBitmap();
					spr.updateCostume();
					spr.applyFilters();
				}
			}
			stagePane.clearCachedBitmap();
			stagePane.updateCostume();
			stagePane.applyFilters();
		}
	}

	public function clearCachedBitmaps():void {
		for(var i:int=0; i<stagePane.numChildren; ++i) {
			var spr:ScratchSprite = (stagePane.getChildAt(i) as ScratchSprite);
			if(spr) spr.clearCachedBitmap();
		}
		stagePane.clearCachedBitmap();

		// unsupported technique that seems to force garbage collection
		try {
			new LocalConnection().connect('foo');
			new LocalConnection().connect('foo');
		} catch (e:Error) {}
	}

	SCRATCH::allow3d
	public function go3D():void {
		if(!render3D || isIn3D) return;

		var i:int = stagePart.getChildIndex(stagePane);
		stagePart.removeChild(stagePane);
		render3D.setStage(stagePane, stagePane.penLayer);
		stagePart.addChildAt(stagePane, i);
		isIn3D = true;
	}

	SCRATCH::allow3d
	public function go2D():void {
		if(!render3D || !isIn3D) return;

		var i:int = stagePart.getChildIndex(stagePane);
		stagePart.removeChild(stagePane);
		render3D.setStage(null, null);
		stagePart.addChildAt(stagePane, i);
		isIn3D = false;
		for(i=0; i<stagePane.numChildren; ++i) {
			var spr:ScratchSprite = (stagePane.getChildAt(i) as ScratchSprite);
			if(spr) {
				spr.clearCachedBitmap();
				spr.updateCostume();
				spr.applyFilters();
			}
		}
		stagePane.clearCachedBitmap();
		stagePane.updateCostume();
		stagePane.applyFilters();
	}

	protected function determineJSAccess():void {
		// After checking for JS access, call initialize().
		initialize();
	}

	private var debugRect:Shape;
	public function showDebugRect(r:Rectangle):void {
		// Used during debugging...
		var p:Point = stagePane.localToGlobal(new Point(0, 0));
		if (!debugRect) debugRect = new Shape();
		var g:Graphics = debugRect.graphics;
		g.clear();
		if (r) {
			g.lineStyle(2, 0xFFFF00);
			g.drawRect(p.x + r.x, p.y + r.y, r.width, r.height);
			addChild(debugRect);
		}
	}

	public function strings():Array {
		return [
			'a copy of the project file on your computer.',
			'Project not saved!', 'Save now', 'Not saved; project did not load.',
			'Save now', 'Saved',
			'Revert', 'Undo Revert', 'Reverting...',
			'Throw away all changes since opening this project?',
		];
	}

	public function viewedObj():ScratchObj { return viewedObject; }
	public function stageObj():ScratchStage { return stagePane; }
	public function projectName():String { return stagePart.projectName(); }
	public function highlightSprites(sprites:Array):void { libraryPart.highlight(sprites); }
	public function refreshImageTab(fromEditor:Boolean):void { imagesPart.refresh(fromEditor); }
	public function refreshSoundTab():void { soundsPart.refresh(); }
	public function selectCostume():void { imagesPart.selectCostume(); }
	public function selectSound(snd:ScratchSound):void { soundsPart.selectSound(snd); }
	public function clearTool():void { CursorTool.setTool(null); topBarPart.clearToolButtons(); }
	public function tabsRight():int { return tabsPart.x + tabsPart.w; }
	public function enableEditorTools(flag:Boolean):void { imagesPart.editor.enableTools(flag); }

	public function get usesUserNameBlock():Boolean {
		return _usesUserNameBlock;
	}

	public function set usesUserNameBlock(value:Boolean):void {
		_usesUserNameBlock = value;
		stagePart.refresh();
	}

	public function updatePalette(clearCaches:Boolean = true):void {
		// Note: updatePalette() is called after changing variable, list, or procedure
		// definitions, so this is a convenient place to clear the interpreter's caches.
		if (isShowing(scriptsPart)) scriptsPart.updatePalette();
		if (clearCaches) runtime.clearAllCaches();
	}

	public function setProjectName(s:String):void {
		if (s.slice(-3) == '.sb') s = s.slice(0, -3);
		if (s.slice(-4) == '.sb2') s = s.slice(0, -4);
		stagePart.setProjectName(s);
	}

	protected var wasEditing:Boolean;
	public function setPresentationMode(enterPresentation:Boolean):void {
		if (enterPresentation) {
			wasEditing = editMode;
			if (wasEditing) {
				setEditMode(false);
				if(jsEnabled) externalCall('tip_bar_api.hide');
			}
		} else {
			if (wasEditing) {
				setEditMode(true);
				if(jsEnabled) externalCall('tip_bar_api.show');
			}
		}
		if (isOffline) {
			stage.displayState = enterPresentation ? StageDisplayState.FULL_SCREEN_INTERACTIVE : StageDisplayState.NORMAL;
		}
		for each (var o:ScratchObj in stagePane.allObjects()) o.applyFilters();

		if (lp) fixLoadProgressLayout();
		stagePane.updateCostume();
		SCRATCH::allow3d { if(isIn3D) render3D.onStageResize(); }
	}

	private function keyDown(evt:KeyboardEvent):void {
		// Escape exists presentation mode.
		if ((evt.charCode == 27) && stagePart.isInPresentationMode()) {
			setPresentationMode(false);
			stagePart.exitPresentationMode();
		}
		// Handle enter key
        //		else if(evt.keyCode == 13 && !stage.focus) {
        //			stagePart.playButtonPressed(null);
        //			evt.preventDefault();
        //			evt.stopImmediatePropagation();
        //		}
		// Handle ctrl-m and toggle 2d/3d mode
		else if(evt.ctrlKey && evt.charCode == 109) {
			SCRATCH::allow3d { isIn3D ? go2D() : go3D(); }
			evt.preventDefault();
			evt.stopImmediatePropagation();
		}
	}

	private function setSmallStageMode(flag:Boolean):void {
		stageIsContracted = flag;
		stagePart.refresh();
		fixLayout();
		libraryPart.refresh();
		tabsPart.refresh();
		stagePane.applyFilters();
		stagePane.updateCostume();
	}

	public function projectLoaded():void {
		removeLoadProgressBox();
		System.gc();
		if (autostart) runtime.startGreenFlags(true);
		saveNeeded = false;

		// translate the blocks of the newly loaded project
		for each (var o:ScratchObj in stagePane.allObjects()) {
			o.updateScriptsAfterTranslation();
		}
	}

	protected function step(e:Event):void {
		// Step the runtime system and all UI components.
        //		Logger.logBrowser("step called");
        //		trace("step called");
		gh.step();
		runtime.stepRuntime();
		Transition.step(null);
		stagePart.step();
		libraryPart.step();
		scriptsPart.step();
		imagesPart.step();
	}

	public function updateSpriteLibrary(sortByIndex:Boolean = false):void { libraryPart.refresh() }
	public function threadStarted():void { stagePart.threadStarted() }

	public function selectSprite(obj:ScratchObj):void {
		if (isShowing(imagesPart)) imagesPart.editor.shutdown();
		if (isShowing(soundsPart)) soundsPart.editor.shutdown();
		viewedObject = obj;
		libraryPart.refresh();
		tabsPart.refresh();
		if (isShowing(imagesPart)) {
			imagesPart.refresh();
		}
		if (isShowing(soundsPart)) {
			soundsPart.currentIndex = 0;
			soundsPart.refresh();
		}
		if (isShowing(scriptsPart)) {
			scriptsPart.updatePalette();
			scriptsPane.viewScriptsFor(obj);
			scriptsPart.updateSpriteWatermark();
		}
	}

	public function setTab(tabName:String):void {
		if (isShowing(imagesPart)) imagesPart.editor.shutdown();
		if (isShowing(soundsPart)) soundsPart.editor.shutdown();
		hide(scriptsPart);
		hide(imagesPart);
		hide(soundsPart);
		if (!editMode) return;
		if (tabName == 'images') {
			show(imagesPart);
			imagesPart.refresh();
		} else if (tabName == 'sounds') {
			soundsPart.refresh();
			show(soundsPart);
		} else if (tabName && (tabName.length > 0)) {
			tabName = 'scripts';
			scriptsPart.updatePalette();
			scriptsPane.viewScriptsFor(viewedObject);
			scriptsPart.updateSpriteWatermark();
			show(scriptsPart);
		}
		show(tabsPart);
		show(stagePart); // put stage in front
		tabsPart.selectTab(tabName);
		lastTab = tabName;
		if (saveNeeded) setSaveNeeded(true); // save project when switching tabs, if needed (but NOT while loading!)
	}

	public function installStage(newStage:ScratchStage):void {
		var showGreenflagOverlay:Boolean = shouldShowGreenFlag();
		stagePart.installStage(newStage, showGreenflagOverlay);
		selectSprite(newStage);
		libraryPart.refresh();
		setTab('scripts');
		scriptsPart.resetCategory();
		wasEdited = false;
	}

	protected function shouldShowGreenFlag():Boolean {
		return !(autostart || editMode);
	}

	protected function addParts():void {
		initTopBarPart();
		stagePart = getStagePart();
		libraryPart = getLibraryPart();
		tabsPart = new TabsPart(this);
		scriptsPart = new ScriptsPart(this);
		imagesPart = new ImagesPart(this);
		soundsPart = new SoundsPart(this);
		addChild(topBarPart);
		addChild(stagePart);
		addChild(libraryPart);
		addChild(tabsPart);
	}

	protected function getStagePart():StagePart {
		return new StagePart(this);
	}

	protected function getLibraryPart():LibraryPart {
		return new LibraryPart(this);
	}

	public function fixExtensionURL(javascriptURL:String):String {
		return javascriptURL;
	}

	// -----------------------------
	// UI Modes and Resizing
	//------------------------------

	public function setEditMode(newMode:Boolean):void {
		Menu.removeMenusFrom(stage);
		editMode = newMode;
		if (editMode) {
			//sm4241 -default design mode
			interp.sageDesignMode = true;
			interp.showAllRunFeedback();
			hide(playerBG);
			show(topBarPart);
			show(libraryPart);
			show(tabsPart);
			setTab(lastTab);
			stagePart.hidePlayButton();
			runtime.edgeTriggersEnabled = true;
		} else {
			addChildAt(playerBG, 0); // behind everything
			playerBG.visible = false;
			hide(topBarPart);
			hide(libraryPart);
			hide(tabsPart);
			setTab(null); // hides scripts, images, and sounds
		}
		stagePane.updateListWatchers();
		show(stagePart); // put stage in front
		fixLayout();
		stagePart.refresh();
	}

	protected function hide(obj:DisplayObject):void { if (obj.parent) obj.parent.removeChild(obj) }
	protected function show(obj:DisplayObject):void { addChild(obj) }
	protected function isShowing(obj:DisplayObject):Boolean { return obj.parent != null }

	public function onResize(e:Event):void {
		fixLayout();
	}

	public function fixLayout():void {
		var w:int = stage.stageWidth;
		var h:int = stage.stageHeight - 1; // fix to show bottom border...

		w = Math.ceil(w / scaleX);
		h = Math.ceil(h / scaleY);

		updateLayout(w, h);
	}

	protected function updateLayout(w:int, h:int):void {
		topBarPart.x = 0;
		topBarPart.y = 0;
		topBarPart.setWidthHeight(w, 28);

		var extraW:int = 2;
		var extraH:int = stagePart.computeTopBarHeight() + 1;
		if (editMode) {
			// adjust for global scale (from browser zoom)

			if (stageIsContracted) {
				stagePart.setWidthHeight(240 + extraW, 180 + extraH, 0.5);
			} else {
				stagePart.setWidthHeight(480 + extraW, 360 + extraH, 1);
			}
			stagePart.x = 5;
			stagePart.y = topBarPart.bottom() + 5;
			fixLoadProgressLayout();
		} else {
			drawBG();
			var pad:int = (w > 550) ? 16 : 0; // add padding for full-screen mode
			var scale:Number = Math.min((w - extraW - pad) / 480, (h - extraH - pad) / 360);
			scale = Math.max(0.01, scale);
			var scaledW:int = Math.floor((scale * 480) / 4) * 4; // round down to a multiple of 4
			scale = scaledW / 480;
			var playerW:Number = (scale * 480) + extraW;
			var playerH:Number = (scale * 360) + extraH;
			stagePart.setWidthHeight(playerW, playerH, scale);
			stagePart.x = int((w - playerW) / 2);
			stagePart.y = int((h - playerH) / 2);
			fixLoadProgressLayout();
			return;
		}
		libraryPart.x = stagePart.x;
		libraryPart.y = stagePart.bottom() + 18;
		libraryPart.setWidthHeight(stagePart.w, h - libraryPart.y);

		tabsPart.x = stagePart.right() + 5;
		tabsPart.y = topBarPart.bottom() + 5;
		tabsPart.fixLayout();

		// the content area shows the part associated with the currently selected tab:
		var contentY:int = tabsPart.y + 27;
		w -= tipsWidth();
		updateContentArea(tabsPart.x, contentY, w - tabsPart.x - 6, h - contentY - 5, h);
	}

	protected function updateContentArea(contentX:int, contentY:int, contentW:int, contentH:int, fullH:int):void {
		imagesPart.x = soundsPart.x = scriptsPart.x = contentX;
		imagesPart.y = soundsPart.y = scriptsPart.y = contentY;
		imagesPart.setWidthHeight(contentW, contentH);
		soundsPart.setWidthHeight(contentW, contentH);
		scriptsPart.setWidthHeight(contentW, contentH);

		if (mediaLibrary) mediaLibrary.setWidthHeight(topBarPart.w, fullH);
		if (frameRateGraph) {
			frameRateGraph.y = stage.stageHeight - frameRateGraphH;
			addChild(frameRateGraph); // put in front
		}

		SCRATCH::allow3d { if (isIn3D) render3D.onStageResize(); }
	}

	private function drawBG():void {
		var g:Graphics = playerBG.graphics;
		g.clear();
		g.beginFill(0);
		g.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
	}

	// -----------------------------
	// Translations utilities
	//------------------------------

	public function translationChanged():void {
		// The translation has changed. Fix scripts and update the UI.
		// directionChanged is true if the writing direction (e.g. left-to-right) has changed.
		for each (var o:ScratchObj in stagePane.allObjects()) {
			o.updateScriptsAfterTranslation();
		}
		var uiLayer:Sprite = app.stagePane.getUILayer();
		for (var i:int = 0; i < uiLayer.numChildren; ++i) {
			var lw:ListWatcher = uiLayer.getChildAt(i) as ListWatcher;
			if (lw) lw.updateTranslation();
		}
		topBarPart.updateTranslation();
		stagePart.updateTranslation();
		libraryPart.updateTranslation();
		tabsPart.updateTranslation();
		updatePalette(false);
		imagesPart.updateTranslation();
		soundsPart.updateTranslation();
	}

	// -----------------------------
	// Menus
	//------------------------------
	public function showFileMenu(b:*):void {
		var m:Menu = new Menu(null, 'File', CSS.topBarColor, 28);
		m.addItem('New', createNewProject);
		m.addLine();

		// Derived class will handle this
		addFileMenuItems(b, m);

		m.showOnStage(stage, b.x, topBarPart.bottom() - 1);
	}

	protected function addFileMenuItems(b:*, m:Menu):void {
		m.addItem('Load Project', runtime.selectProjectFile);
		m.addItem('Save Project', exportProjectToFile);
		m.addItem('About', showAboutDialog);

		if (Scratch.app.interp.sageDesignMode) {
			/*
			var fileRef:FileReference= new FileReference();
            //			button.addEventListener(MouseEvent.CLICK, onButtonClick);


			function onButtonClick(e:MouseEvent):void {
				trace("onbutonclick called");
				//fileRef.browse([new FileFilter("Documents", "*.json")]);
				fileRef.browse([new FileFilter("All Files (*.*)","*.*")]);

				fileRef.addEventListener(Event.SELECT, onFileSelected);
			}

			function onFileSelected(e:Event):void {
				trace("onfileselected called");
				fileRef.addEventListener(Event.COMPLETE, onFileLoaded);
				fileRef.load();
			}

			function onFileLoaded(e:Event):void {
				//var loader:URLLoader = new URLLoader();
				//loader.load(e.target.data);

				//addChild(loader);

				//var data:ByteArray = fileReference["data"];
				var lol:Object = util.JSON.parse(e.target.data);
				Specs.pointDict = lol;
				trace(lol);
			}*/

		//	m.addItem('Save Point Configuration');

			function configFileLoaded(e:Event):void {
				trace("lolfunc called");
				var lol:Object = util.JSON.parse(e.target.data);
				Specs.pointDict = lol;
				trace("json: " + lol);
			}

            function configFileLoadedFromString(s:String):void {
                trace("Config File Loaded From String called");

                var lol:Object = util.JSON.parse(s);
                Specs.pointDict = lol;
                trace("json: " + lol);
                topBarPart.refresh();
                stagePart.refresh();
            }

			function selectConfigFile():void {
                var configFileNameList:Array = [];
                var configFileList:Array = [];
                // fetch list of config file from server
                var currentPageIndex:int = 0;
                var configPerPage:int = 5;
                var maxPageIndex:int = 0;
                var hasCheckedServer:Boolean = false;

                // Prompt user for a file name and load that file.
                var configFileListDialog:DialogBox = new DialogBox(null);
                var checkingDialog:DialogBox = new DialogBox(null);
                checkingDialog.addTitle('Checking Server');
                checkingDialog.addText('Checking Server...');

                var timeoutTimer:Timer = new Timer(1000, 5);
                timeoutTimer.addEventListener(TimerEvent.TIMER, checkConfigExists);
                timeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE, timeout);
                timeoutTimer.start();

                function checkConfigExists():void {
                    if (!hasCheckedServer) {
                        var payload:Object = {};
                        payload.event = "FETCH_POINT_CONFIG";
                        payload.id = sid;
                        payload.assignmentID = assignmentID;
                        try {
                            client.writeUTFBytes(util.JSON.stringify(payload));
                            Logger.logBrowser(util.JSON.stringify(payload));
                            client.flush();
                            hasCheckedServer = true;
                        } catch (e) {
                            trace("socket error: " + e.toString());
                        }

                    }

                    if (hasConfigResponse.hasOwnProperty("configList")) {
                        checkingDialog.cancel();
                        timeoutTimer.stop();
                        var configJsonList:Object = util.JSON.parse(hasConfigResponse.configList.toString());
                        for (var i:int = 0; i < configJsonList.length; i++) {
                            if (configJsonList[i].id == sid) {
                                configFileNameList.push(configJsonList[i].configName + " by you");
                            } else {
                                configFileNameList.push(configJsonList[i].configName + " by " + configJsonList[i].id);
                            }
                            configFileList.push(configJsonList[i].pointConfig);
                        }
                        maxPageIndex = int(configFileNameList.length / configPerPage);
                        displayConfigList();
                    }
                }

                function timeout():void {
                    checkingDialog.cancel();
                    var timeoutDialog:DialogBox = new DialogBox(null);
                    timeoutDialog.addTitle("Server Error");
                    timeoutDialog.addText("Server encounters some issue. Please try again.");
                    timeoutDialog.addButton("Close", null);
                    timeoutDialog.showOnStage(stage);
                    hasCheckedServer = false;
                }

                function selected(s:String):void {
                    var configFile:String = configFileList[configFileNameList.indexOf(s)].toString();
                    configFileLoadedFromString(configFile);
                    hasCheckedServer = false;
                }

                function previousPage():void {
                    if (currentPageIndex > 0) {
                        currentPageIndex--;
                    }
                    displayConfigList();
                }

                function nextPage():void{
                    if (currentPageIndex < maxPageIndex) {
                        currentPageIndex++;
                    }
                    displayConfigList();
                }
                function cancel():void {
                    configFileListDialog.cancel();
                    hasCheckedServer = false;
                }

                function displayConfigList():void {
                    configFileListDialog = new DialogBox();
                    configFileListDialog.addTitle("Load Config List");
                    if (currentPageIndex == maxPageIndex) {
                        for (var index:int = currentPageIndex * configPerPage;
                             index < configFileNameList.length; index++) {
                            configFileListDialog.addMenuButton(Translator.map(configFileNameList[index]), selected);
                        }
                    } else {
                        for (var i:int = currentPageIndex * configPerPage;
                             i < (currentPageIndex + 1) * configPerPage; i++) {
                            configFileListDialog.addMenuButton(Translator.map(configFileNameList[i]), selected);
                        }
                    }

                    configFileListDialog.addButton(Translator.map("Prev Page"), previousPage);
                    configFileListDialog.addButton(Translator.map("Next Page"), nextPage);
                    configFileListDialog.addButton(Translator.map("Cancel"), cancel);
                    configFileListDialog.showOnStage(stage);
                }

                checkingDialog.showOnStage(stage);
			}

			function saveConfigFile():void {
                var DEFAULT_CONFIG_NAME:String = "points_config.json";
                var userEnteredName:String = DEFAULT_CONFIG_NAME;
                var d:DialogBox = new DialogBox();
                var hasCheckedServer:Boolean = false;
                var checkingDialog:DialogBox = new DialogBox(null);
                checkingDialog.addTitle('Checking Server');
                checkingDialog.addText('Checking Server...');

                var timeoutTimer:Timer = new Timer(1000, 5);

                function checkDuplicate(): void {
                    if (!hasCheckedServer) {
                        var checkDuplicatePayload:Object = {};
                        checkDuplicatePayload.event = "CHECK_DUPLICATE_NAME";
                        checkDuplicatePayload.assignmentID = assignmentID;
                        checkDuplicatePayload.id = sid;
                        checkDuplicatePayload.configName = userEnteredName;
                        var stringPayload:String = util.JSON.stringify(checkDuplicatePayload);
                        try {
                            client.writeUTFBytes(stringPayload);
                            Logger.logBrowser(stringPayload.slice(1, stringPayload.length-1).split("\n").join(" "));
                            client.flush();
                            hasCheckedServer = true;
                        } catch (e) {
                            trace("socket error: " + e.toString());
                        }

                    }

                    trace("Check Point Configuration Duplicate");
                    // wait for server response
                    if (hasDuplicateResponse.hasOwnProperty("isDuplicate")) {
                        checkingDialog.cancel();
                        timeoutTimer.stop();
                        if (hasDuplicateResponse.isDuplicate) {
                            d = new DialogBox();
                            d.addTitle('Point Configuration Exists');
                            d.addText("The point configuration name you entered: " + userEnteredName +
                                    " has been used for this game. Do you want to overwrite?");
                            d.addButton("Overwrite", submit);
                            d.addButton("Go back", goBack);
                            d.showOnStage(stage);
                        } else {
                            submit();
                        }
                    }
                }

                function submit():void {
                    var jsonString:String=util.JSON.stringify(Specs.pointDict);
                    trace("jsonstring: " + jsonString);
                    // jw3564 save point configuration to server instead of local
                    var payload:Object = {};
                    payload.event = "SAVE_POINT_CONFIG";
                    payload.pointConfig = jsonString;
                    payload.assignmentID = assignmentID;
                    payload.configName = userEnteredName;
                    payload.id = sid;
                    try {
                        client.writeUTFBytes(util.JSON.stringify(payload));
                        Logger.logBrowser(util.JSON.stringify(payload));
                        client.flush();
                        hasDuplicateResponse = {};

                    } catch (e) {
                        trace("socket error: " + e.toString());
                    }
                }
                function goBack():void {
                    d.cancel();
                    hasDuplicateResponse = {};
                    displaySaveConfirmation();
                }
                function cancel():void {
                    d.cancel();
                }
                function timeout():void {
                    checkingDialog.cancel();
                    var timeoutDialog:DialogBox = new DialogBox(null);
                    timeoutDialog.addTitle("Server Error");
                    timeoutDialog.addText("Server encounters some issue. Please try again.");
                    timeoutDialog.addButton("Close", null);
                    timeoutDialog.showOnStage(stage);
                }
                function save():void {
                    d.cancel();
                    hasCheckedServer = false;
                    userEnteredName = d.getField('Configuration Name');
                    if (userEnteredName.indexOf(" ") >= 0) {
                        var invalidDialog:DialogBox = new DialogBox(null);
                        invalidDialog.addTitle("Invalid Config File Name");
                        invalidDialog.addText("The config file name you entered \"" + userEnteredName + "\" is invalid.");
                        invalidDialog.addButton("Close", null);
                        invalidDialog.showOnStage(stage);
                        return;
                    }
                    timeoutTimer.addEventListener(TimerEvent.TIMER, checkDuplicate);
                    timeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE, timeout);
                    timeoutTimer.start();
                    checkingDialog.showOnStage(stage);
                }

                function displaySaveConfirmation(): void {
                    d = new DialogBox(null);
                    d.addTitle('Save Point Configuration');
                    d.addField('Configuration Name', 150, "points_config.json", true);
                    d.addButton('Save', save);
                    d.addButton('Cancel', cancel);
                    d.showOnStage(stage);
                }
                displaySaveConfirmation();
			}

			m.addItem('Load Point Configuration', selectConfigFile);
			m.addItem('Save Point Configuration', saveConfigFile);

		}

		if (canUndoRevert()) {
			m.addLine();
			m.addItem('Undo Revert', undoRevert);
		} else if (canRevert()) {
			m.addLine();
			m.addItem('Revert', revertToOriginalProject);
		}

		if (b.lastEvent.shiftKey) {
			m.addLine();
			m.addItem('Save Project Summary', saveSummary);
		}
		if (b.lastEvent.shiftKey && jsEnabled) {
			m.addLine();
			m.addItem('Import experimental extension', function():void {
				function loadJSExtension(dialog:DialogBox):void {
					var url:String = dialog.getField('URL').replace(/^\s+|\s+$/g, '');
					if (url.length == 0) return;
					externalCall('ScratchExtensions.loadExternalJS', null, url);
				}
				var d:DialogBox = new DialogBox(loadJSExtension);
				d.addTitle('Load Javascript Scratch Extension');
				d.addField('URL', 120);
				d.addAcceptCancelButtons('Load');
				d.showOnStage(app.stage);
			});
		}
	}

	public function showEditMenu(b:*):void {
		var m:Menu = new Menu(null, 'More', CSS.topBarColor, 28);
		m.addItem('Undelete', runtime.undelete, runtime.canUndelete());
		m.addLine();
		m.addItem('Small stage layout', toggleSmallStage, true, stageIsContracted);
		m.addItem('Turbo mode', toggleTurboMode, true, interp.turboMode);
		m.addItem('SAGE Design mode', toggleSageDesignMode, !interp.isStudent, interp.sageDesignMode);
        m.addItem('SAGE Design mode (Parsons)', togglePreciseMode, true, interp.preciseMode);
		m.addItem('SAGE Play mode', toggleSagePlayMode, true, interp.sagePlayMode);

		addEditMenuItems(b, m);
		var p:Point = b.localToGlobal(new Point(0, 0));
		m.showOnStage(stage, b.x, topBarPart.bottom() - 1);
	}

	protected function addEditMenuItems(b:*, m:Menu):void {
		m.addLine();
		m.addItem('Edit block colors', editBlockColors);
	}

	protected function editBlockColors():void {
		var d:DialogBox = new DialogBox();
		d.addTitle('Edit Block Colors');
		d.addWidget(new BlockColorEditor());
		d.addButton('Close', d.cancel);
		d.showOnStage(stage, true);
	}

	protected function canExportInternals():Boolean {
		return false;
	}

	private function showAboutDialog():void {
		var aboutContent:String = (
				'\n\nCopyright © 2012 MIT Media Laboratory' +
				'\nAll rights reserved.' +
				'\n\nPlease do not distribute!'
		);
		// SCRATCH::sageVersion { aboutContent += '\n\nSage Version: ' + SCRATCH::sageVersion; }
		DialogBox.notify('Scratch 2.0 ' + versionString, aboutContent, stage);
	}

	protected function createNewProject(ignore:* = null):void {
		function clearProject():void {
			startNewProject('', '');
			setProjectName('Untitled');
			Scratch.app.points = 0;
			scriptsPart.setSagePalettes(sagePalettesDefault);
			topBarPart.refresh();
			stagePart.refresh();
		}
		saveProjectAndThen(clearProject);
	}

	protected function saveProjectAndThen(postSaveAction:Function = null):void {
		// Give the user a chance to save their project, if needed, then call postSaveAction.
		function doNothing():void {}
		function cancel():void { d.cancel(); }
		function proceedWithoutSaving():void { d.cancel(); postSaveAction() }
		function save():void {
			d.cancel();
			exportProjectToFile(); // if this succeeds, saveNeeded will become false
			if (!saveNeeded) postSaveAction();
		}
		if (postSaveAction == null) postSaveAction = doNothing;
		if (!saveNeeded) {
			postSaveAction();
			return;
		}
		var d:DialogBox = new DialogBox();
		d.addTitle(Translator.map('Save project') + '?');
		d.addButton('Save', save);
		d.addButton('Don\'t save', proceedWithoutSaving);
		d.addButton('Cancel', cancel);
		d.showOnStage(stage);
	}


	public function exportProjectToFile(fromJS:Boolean = false):void {
		function ioErrorHandler(e:Event):void{
			Logger.logAll("cannot save IOError "+e.toString());
		}

		function fileSaved(e:Event):void {
			Logger.logBrowser("file saved locally");
			if (!fromJS) setProjectName(e.target.name);
        }
		if (loadInProgress) return;
		this.doSave = true;
        var projIO:ProjectIO = new ProjectIO(this);
		var zipData:ByteArray;
        function squeakSoundsConverted():void {
            scriptsPane.saveScripts(false);
            var defaultName:String = (projectName().length > 0) ? projectName() + '.sb2' : 'project.sb2';
            zipData = projIO.encodeProjectAsZipFile(stagePane);
            var file:FileReference = new FileReference();
            file.addEventListener(Event.COMPLETE, fileSaved);
            file.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
            file.save(zipData, fixFileName(defaultName));
			//Logger.logBrowser(fixFileName(defaultName));
        }
		try{
            projIO.convertSqueakSounds(stagePane, squeakSoundsConverted);
		}catch(error:Error){
            Logger.logAll("something happened "+error.toString());
		}finally{
            uploadToServer(zipData);
			this.doSave = false;
		}
        Logger.logAll("end of saving");
	}

    public function exportProjectToServer(fromJS:Boolean = false): void {
        // save formatted json to database
        function calculateRemainingSeconds(startTime:String, endTime:String, gameLength: int): String {
            trace ("endTime" + endTime + " parsed: " + parseInt(endTime));
            trace ("startTime" + startTime + "parsed: " + parseInt(startTime));
            var remainingTime:int = gameLength - (parseInt(endTime) - parseInt(startTime)) / 1000;
            return remainingTime > 0 ? remainingTime.toString() : "0";
        }

        var projIO:ProjectIO = new ProjectIO(this);
        var zipData:ByteArray = projIO.encodeProjectAsZipFile(stagePane);
		//Logger.logBrowser(zipData)
        var allScripts:Array = [];
        for each (var b:Block in stagePane.scripts) {
            allScripts.push([b.x, b.y, BlockIO.stackToArray(b)]);
        }
        var payload:Object = {};
        payload.event = "SUBMISSION";
        payload.studentID = sid;
        payload.assignmentID = assignmentID;
        payload.objectiveID = objectiveID;
        payload.score = getPoints().toString();
        payload.blocks = allScripts;
        payload.hintUsage = paletteBuilder.getHintCount().toString();
        payload.startTime = startTime;
        payload.endTime = new Date().valueOf().toString();
        payload.meaningfulMoves = meaningfulMoves.toString();
        payload.maxScoreForGame = maxScoreForGame.toString();
        payload.remainingSeconds = calculateRemainingSeconds(startTime, payload.endTime,
                paletteBuilder.getInputTimeInSeconds());
        payload.submitMsg = submitMsg;
        payload.selfExplanation = selfExplanation;
        payload.sb2File = zipData.toString();
		//Logger.logBrowser("hi");
		//exportProjectToFile();
        Logger.logBrowser("SUBMIT STUDENT ANSWER");
		var file:FileReference = new FileReference();
        //file.addEventListener(Event.COMPLETE, fileSaved);
        //file.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
        //file.save(zipData, "testingtesting");
		//Logger.logBrowser("hello!! ");
        trace("Submission payload: " + util.JSON.stringify(payload, true));
        var stringPayload:String = util.JSON.stringify(payload);
        
		try {
            client.writeUTFBytes(stringPayload);
            Logger.logBrowser(stringPayload.slice(1, stringPayload.length-1).split("\n").join(" "));
            client.flush();
            trace("submit clear");
        } catch (e) {
            trace("socket error: " + e.toString());
        }
    }

	public function uploadToServer(data:ByteArray):void{
		// TODO : add logic if scratch is in play mode then abort uploading to server
		if(this.interp.sagePlayMode){
			return
		}

		var serverUrl:String =  this.baseUrl+"/games/post";
		if(this.baseUrl) {
            //var serverUrl:String =  "http://dev.cu-sage.org:8081/games/post";
            var loader:Uploader = new Uploader(serverUrl, "upload saving");
            Logger.logBrowser(serverUrl);
            loader.setLoaderDataFormat(URLLoaderDataFormat.BINARY);
            loader.setData(data, ((this.assignmentID == null) ? "game" : this.assignmentID) + ".sb2");

            try {
                Logger.logBrowser("uploading game started")
                loader.upload();
                Logger.logBrowser("uploading game finished")
            } catch (error:Error) {
                Logger.logBrowser("upload failed"+error.message);
            }
        }else{
            // Logger.logBrowser("base url is missing, not uploading");
        }
	}

	public static function fixFileName(s:String):String {
		// Replace illegal characters in the given string with dashes.
		const illegal:String = '\\/:*?"<>|%';
		var result:String = '';
		for (var i:int = 0; i < s.length; i++) {
			var ch:String = s.charAt(i);
			if ((i == 0) && ('.' == ch)) ch = '-'; // don't allow leading period
			result += (illegal.indexOf(ch) > -1) ? '-' : ch;
		}
		return result;
	}

	public function saveSummary():void {
		var name:String = (projectName() || "project") + ".txt";
		var file:FileReference = new FileReference();
		file.save(stagePane.getSummary(), fixFileName(name));
	}

	public function toggleSmallStage():void {
		setSmallStageMode(!stageIsContracted);
	}

	public function toggleTurboMode():void {
		interp.turboMode = !interp.turboMode;
		stagePart.refresh();
	}

    // pz2244
    public function togglePreciseMode():void {
        interp.preciseMode = !interp.preciseMode;
        interp.sageDesignMode = true;
        stagePart.refresh();
    }

	//yc2937
	//update elements when switching to design mode

	public function toggleSageDesignMode(): void {
		interp.sageDesignMode = !interp.sageDesignMode;
		interp.sagePlayMode = false;
		stagePart.refresh();
		viewedObject.updateScriptsAfterTranslation(); // resets ScriptsPane
	}

	//update elements when switching to play mode
	public function toggleSagePlayMode(): void {
		interp.sagePlayMode = !interp.sagePlayMode;
		interp.sageDesignMode = false;

        if (!interp.freeMode) {
            interp.preciseMode = true;
            interp.studentParsonsMode = true;
            paletteBuilder.showBlocksForCategory(Specs.parsonsCategory, false);
        }
		stagePart.refresh();
		viewedObject.updateScriptsAfterTranslation(); // resets ScriptsPane
	}

	public function handleTool(tool:String, evt:MouseEvent):void { }

	public function showBubble(text:String, x:* = null, y:* = null, width:Number = 0):void {
		if (x == null) x = stage.mouseX;
		if (y == null) y = stage.mouseY;
		gh.showBubble(text, Number(x), Number(y), width);
	}

	// -----------------------------
	// Project Management and Sign in
	//------------------------------

	public function setLanguagePressed(b:IconButton):void {
		function setLanguage(lang:String):void {
			Translator.setLanguage(lang);
			languageChanged = true;
		}
		if (Translator.languages.length == 0) return; // empty language list
		var m:Menu = new Menu(setLanguage, 'Language', CSS.topBarColor, 28);
		if (b.lastEvent.shiftKey) {
			m.addItem('import translation file');
			m.addItem('set font size');
			m.addLine();
		}
		for each (var entry:Array in Translator.languages) {
			m.addItem(entry[1], entry[0]);
		}
		var p:Point = b.localToGlobal(new Point(0, 0));
		m.showOnStage(stage, b.x, topBarPart.bottom() - 1);
	}

	public function startNewProject(newOwner:String, newID:String):void {
		runtime.installNewProject();
		projectOwner = newOwner;
		projectID = newID;
		projectIsPrivate = true;
		loadInProgress = false;
	}

	// -----------------------------
	// Save status
	//------------------------------

	public var saveNeeded:Boolean;

	public function setSaveNeeded(saveNow:Boolean = false):void {
		saveNow = false;
		// Set saveNeeded flag and update the status string.
		saveNeeded = true;
		if (!wasEdited) saveNow = true; // force a save on first change
		clearRevertUndo();
	}

	protected function clearSaveNeeded():void {
		// Clear saveNeeded flag and update the status string.
		function twoDigits(n:int):String { return ((n < 10) ? '0' : '') + n }
		saveNeeded = false;
		wasEdited = true;
	}

	// -----------------------------
	// Project Reverting
	//------------------------------

	protected var originalProj:ByteArray;
	private var revertUndo:ByteArray;

	public function saveForRevert(projData:ByteArray, isNew:Boolean, onServer:Boolean = false):void {
		originalProj = projData;
		revertUndo = null;
	}

	protected function doRevert():void {
		runtime.installProjectFromData(originalProj, false);
	}

	protected function revertToOriginalProject():void {
		function preDoRevert():void {
			revertUndo = new ProjectIO(Scratch.app).encodeProjectAsZipFile(stagePane);
			doRevert();
		}
		if (!originalProj) return;
		DialogBox.confirm('Throw away all changes since opening this project?', stage, preDoRevert);
	}

	protected function undoRevert():void {
		if (!revertUndo) return;
		runtime.installProjectFromData(revertUndo, false);
		revertUndo = null;
	}

	protected function canRevert():Boolean { return originalProj != null }
	protected function canUndoRevert():Boolean { return revertUndo != null }
	private function clearRevertUndo():void { revertUndo = null }

	public function addNewSprite(spr:ScratchSprite, showImages:Boolean = false, atMouse:Boolean = false):void {
        var c:ScratchCostume, byteCount:int;
        for each (c in spr.costumes) {
            if (!c.baseLayerData) c.prepareToSave()
            byteCount += c.baseLayerData.length;
        }
        if (!okayToAdd(byteCount)) return; // not enough room
        spr.objName = stagePane.unusedSpriteName(spr.objName);
        spr.indexInLibrary = 1000000; // add at end of library
        var xpos:Number = int(200 * Math.random() - 100);
        var ypos:Number = int(100 * Math.random() - 50);
        if (atMouse) {
            //spr.setScratchXY(stagePane.scratchMouseX(), stagePane.scratchMouseY());
            xpos = stagePane.scratchMouseX();
            ypos = stagePane.scratchMouseY();
        }
        
        spr.setScratchXY(xpos, ypos);
        spr.initX = xpos;
        spr.initY = ypos;
        spr.initDirection = 90;
        spr.initRotationStyle = 'normal';

        //default whenGreenFlag block
        var default_b1:Block = new Block("when @greenFlag clicked", "h", Specs.categories[5][2], "whenGreenFlag", null, false, null);
        spr.scripts.push(default_b1);

        stagePane.addChild(spr);
        selectSprite(spr);
        setTab(showImages ? 'images' : 'scripts');
        setSaveNeeded(true);
        libraryPart.refresh();
        for each (c in spr.costumes) {
            if (ScratchCostume.isSVGData(c.baseLayerData)) c.setSVGData(c.baseLayerData, false);
        }

    }

	public function addSound(snd:ScratchSound, targetObj:ScratchObj = null):void {
		if (snd.soundData && !okayToAdd(snd.soundData.length)) return; // not enough room
		if (!targetObj) targetObj = viewedObj();
		snd.soundName = targetObj.unusedSoundName(snd.soundName);
		targetObj.sounds.push(snd);
		setSaveNeeded(true);
		if (targetObj == viewedObj()) {
			soundsPart.selectSound(snd);
			setTab('sounds');
		}
	}

	public function addCostume(c:ScratchCostume, targetObj:ScratchObj = null):void {
		if (!c.baseLayerData) c.prepareToSave();
		if (!okayToAdd(c.baseLayerData.length)) return; // not enough room
		if (!targetObj) targetObj = viewedObj();
		c.costumeName = targetObj.unusedCostumeName(c.costumeName);
		targetObj.costumes.push(c);
		targetObj.showCostumeNamed(c.costumeName);
		setSaveNeeded(true);
		if (targetObj == viewedObj()) setTab('images');
	}

	public function okayToAdd(newAssetBytes:int):Boolean {
		// Return true if there is room to add an asset of the given size.
		// Otherwise, return false and display a warning dialog.
		const assetByteLimit:int = 50 * 1024 * 1024; // 50 megabytes
		var assetByteCount:int = newAssetBytes;
		for each (var obj:ScratchObj in stagePane.allObjects()) {
			for each (var c:ScratchCostume in obj.costumes) {
				if (!c.baseLayerData) c.prepareToSave();
				assetByteCount += c.baseLayerData.length;
			}
			for each (var snd:ScratchSound in obj.sounds) assetByteCount += snd.soundData.length;
		}
		if (assetByteCount > assetByteLimit) {
			var overBy:int = Math.max(1, (assetByteCount - assetByteLimit) / 1024);
			DialogBox.notify(
				'Sorry!',
				'Adding that media asset would put this project over the size limit by ' + overBy + ' KB\n' +
				'Please remove some costumes, backdrops, or sounds before adding additional media.',
				stage);
			return false;
		}
		return true;
	}
	// -----------------------------
	// Flash sprite (helps connect a sprite on the stage with a sprite library entry)
	//------------------------------

	public function flashSprite(spr:ScratchSprite):void {
		function doFade(alpha:Number):void { box.alpha = alpha }
		function deleteBox():void { if (box.parent) { box.parent.removeChild(box) }}
		var r:Rectangle = spr.getVisibleBounds(this);
		var box:Shape = new Shape();
		box.graphics.lineStyle(3, CSS.overColor, 1, true);
		box.graphics.beginFill(0x808080);
		box.graphics.drawRoundRect(0, 0, r.width, r.height, 12, 12);
		box.x = r.x;
		box.y = r.y;
		addChild(box);
		Transition.cubic(doFade, 1, 0, 0.5, deleteBox);
	}

	// -----------------------------
	// Download Progress
	//------------------------------

	public function addLoadProgressBox(title:String):void {
		removeLoadProgressBox();
		lp = new LoadProgress();
		lp.setTitle(title);
		stage.addChild(lp);
		fixLoadProgressLayout();
	}

	public function removeLoadProgressBox():void {
		if (lp && lp.parent) lp.parent.removeChild(lp);
		lp = null;
	}

	private function fixLoadProgressLayout():void {
		if (!lp) return;
		var p:Point = stagePane.localToGlobal(new Point(0, 0));
		lp.scaleX = stagePane.scaleX;
		lp.scaleY = stagePane.scaleY;
		lp.x = int(p.x + ((stagePane.width - lp.width) / 2));
		lp.y = int(p.y + ((stagePane.height - lp.height) / 2));
	}

	// -----------------------------
	// Frame rate readout (for use during development)
	//------------------------------

	private var frameRateReadout:TextField;
	private var firstFrameTime:int;
	private var frameCount:int;

	protected function addFrameRateReadout(x:int, y:int, color:uint = 0):void {
		frameRateReadout = new TextField();
		frameRateReadout.autoSize = TextFieldAutoSize.LEFT;
		frameRateReadout.selectable = false;
		frameRateReadout.background = false;
		frameRateReadout.defaultTextFormat = new TextFormat(CSS.font, 12, color);
		frameRateReadout.x = x;
		frameRateReadout.y = y;
		addChild(frameRateReadout);
		frameRateReadout.addEventListener(Event.ENTER_FRAME, updateFrameRate);
	}

	private function updateFrameRate(e:Event):void {
		frameCount++;
		if (!frameRateReadout) return;
		var now:int = getTimer();
		var msecs:int = now - firstFrameTime;
		if (msecs > 500) {
			var fps:Number = Math.round((1000 * frameCount) / msecs);
			frameRateReadout.text = fps + ' fps (' + Math.round(msecs / frameCount) + ' msecs)';
			firstFrameTime = now;
			frameCount = 0;
		}
	}

	// TODO: Remove / no longer used
	private const frameRateGraphH:int = 150;
	private var frameRateGraph:Shape;
	private var nextFrameRateX:int;
	private var lastFrameTime:int;

	private function addFrameRateGraph():void {
		addChild(frameRateGraph = new Shape());
		frameRateGraph.y = stage.stageHeight - frameRateGraphH;
		clearFrameRateGraph();
		stage.addEventListener(Event.ENTER_FRAME, updateFrameRateGraph);
	}

	public function clearFrameRateGraph():void {
		var g:Graphics = frameRateGraph.graphics;
		g.clear();
		g.beginFill(0xFFFFFF);
		g.drawRect(0, 0, stage.stageWidth, frameRateGraphH);
		nextFrameRateX = 0;
	}

	private function updateFrameRateGraph(evt:*):void {
		var now:int = getTimer();
		var msecs:int = now - lastFrameTime;
		lastFrameTime = now;
		var c:int = 0x505050;
		if (msecs > 40) c = 0xE0E020;
		if (msecs > 50) c = 0xA02020;

		if (nextFrameRateX > stage.stageWidth) clearFrameRateGraph();
		var g:Graphics = frameRateGraph.graphics;
		g.beginFill(c);
		var barH:int = Math.min(frameRateGraphH, msecs / 2);
		g.drawRect(nextFrameRateX, frameRateGraphH - barH, 1, barH);
		nextFrameRateX++;
	}

	// -----------------------------
	// Camera Dialog
	//------------------------------

	public function openCameraDialog(savePhoto:Function):void {
		closeCameraDialog();
		cameraDialog = new CameraDialog(savePhoto);
		cameraDialog.fixLayout();
		cameraDialog.x = (stage.stageWidth - cameraDialog.width) / 2;
		cameraDialog.y = (stage.stageHeight - cameraDialog.height) / 2;
		addChild(cameraDialog);
	}

	public function closeCameraDialog():void {
		if (cameraDialog) {
			cameraDialog.closeDialog();
			cameraDialog = null;
		}
	}

	// Misc.
	public function createMediaInfo(obj:*, owningObj:ScratchObj = null):MediaInfo {
		return new MediaInfo(obj, owningObj);
	}

	static public function loadSingleFile(fileLoaded:Function, filters:Array = null):void {
		function fileSelected(event:Event):void {
			if (fileList.fileList.length > 0) {
				var file:FileReference = FileReference(fileList.fileList[0]);
				file.addEventListener(Event.COMPLETE, fileLoaded);
				file.load();
			}
		}

		var fileList:FileReferenceList = new FileReferenceList();
		fileList.addEventListener(Event.SELECT, fileSelected);
		try {
			// Ignore the exception that happens when you call browse() with the file browser open
			fileList.browse(filters);
		} catch(e:*) {}

	}

	public function updateIdCt():void{
		this.blockIdCt++;
	}

	// for hinting
	public function getScriptsPart():ScriptsPart {
		return this.scriptsPart;
	}

	// -----------------------------
	// External Interface abstraction
	//------------------------------

	public function externalInterfaceAvailable():Boolean {
		return false;
	}

	public function externalCall(functionName:String, returnValueCallback:Function = null, ...args):void {
		throw new IllegalOperationError('Must override this function.');
	}

	public function addExternalCallback(functionName:String, closure:Function):void {
		throw new IllegalOperationError('Must override this function.');
	}
}}
