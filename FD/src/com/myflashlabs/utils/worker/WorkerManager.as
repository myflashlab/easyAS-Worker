// =================================================================================================
//	
//	The MIT License (MIT)
//
//	Copyright (c) 2013-2016 MyFlashLabs.com
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//	
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.
//
//	used and modified:
//	https://github.com/bortsen/worker-from-class
//	https://github.com/claus/as3swf
//	
// =================================================================================================

package com.myflashlabs.utils.worker 
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.system.MessageChannel;
	import flash.system.Worker;
	import flash.system.WorkerState;
	import flash.utils.ByteArray;
	import flash.utils.describeType;
	import flash.utils.getQualifiedClassName;
	import flash.utils.setTimeout;
	
	/**
	 * ...
	 * @author Hadi Tavakoli - 1/29/2016 1:17 AM
	 */
	public class WorkerManager extends EventDispatcher 
	{
		public static const VERSION:String = "1.0";
		
		private var _worker:Worker;
		private var _incomingChannel:MessageChannel;
		private var _outgoingChannel:MessageChannel;
		
		private var _parseClasses:Boolean;
		private var _class:Class;
		private var _bytes:ByteArray;
		private var _delegate:*;
		private var _giveAppPrivileges:Boolean;
		private var _debugMode:Boolean = false;
		
		private var _resultBox:Array = [];
		private var _progressBox:Array = [];
		
		public function WorkerManager($class:Class, $bytes:ByteArray, $delegate:*) 
		{
			_class = $class;
			_bytes = $bytes;
			_delegate = $delegate;
			_giveAppPrivileges = true;
			_parseClasses = false;
			
			// turn debugging on if we're building the main thread in debug mode
			turnDebugModeOn()
		}
		
// ------------------------------------------------------------------- functions

		private function onWorkerState(e:Event):void
		{
			// from my expirence it seems like worker start progress may take a few miliseconds, to avoid errors we will dispatch states with a short delay!
			setTimeout(go, 500);
			function go():void
			{
				if (_worker.state == WorkerState.TERMINATED)
				{
					// remove listeners
					_worker.removeEventListener(Event.WORKER_STATE, onWorkerState);
					_incomingChannel.removeEventListener(Event.CHANNEL_MESSAGE, onMessage);
					
					// empty the function references
					_resultBox = [];
					_progressBox = [];
				}
				
				dispatchEvent(new Event(e.type, e.bubbles, e.cancelable));
			}
		}
		
		private function onMessage(e:Event):void
		{
			var arr:Array = _incomingChannel.receive();
			
			// shift out the first parameter
			var firstParameter:String = arr.shift();
			var workerMethod:String;
			
			// check if this is a a result or a progress
			var i:int;
			var lng:int;
			var obj:Object;
			if (firstParameter == "type:progress")
			{
				workerMethod = arr.shift();
				
				lng = _progressBox.length;
				for (i = 0; i < lng; i++) 
				{
					obj = _progressBox[i];
					if (obj.workerMethod == workerMethod)
					{
						//removeFunc(_progressBox, workerMethod);
						obj.onProgressFunc.apply(null, arr);
						return;
					}
				}
			}
			else 
			{
				workerMethod = firstParameter;
				
				lng = _resultBox.length;
				for (i = 0; i < lng; i++) 
				{
					obj = _resultBox[i];
					if (obj.workerMethod == workerMethod)
					{
						removeFunc(_resultBox, workerMethod);
						removeFunc(_progressBox, workerMethod);
						obj.onResultFunc.apply(null, arr);
						return;
					}
				}
			}
			
			trace("no registered function found to send the results back to!")
		}

// ------------------------------------------------------------------- helpful functions

		private function turnDebugModeOn():void
		{
			var stackTrace:String = new Error().getStackTrace();
			if (stackTrace && stackTrace.search(/:[0-9]+]$/m) > -1)
			{
				_debugMode = true;
			}
			
			trace("NOTICE: Workers debug mode is on. Build your app in release mode and debug mode will automatically go off.");
		}
		
		protected function getFunctionName(callee:Function):String 
		{
			var parent:Object = _delegate;
			for each (var m:XML in describeType(parent)..method)
			{
				if (parent[m.@name] == callee) return m.@name;
			}
			return "not found";
		}
		
		private function removeFunc($from:Array, $workerMethod:String):void
		{
			var obj:Object;
			for (var i:int = 0; i < $from.length; i++) 
			{
				obj = $from[i];
				if (obj.workerMethod == $workerMethod)
				{
					$from.splice(i, 1);
					return;
				}
			}
		}

// ------------------------------------------------------------------- methods

		public function command($workerMethod:String, $onProgressFunc:Function, $onResultFunc:Function, ...$params):void
		{
			// register the command so we can later return the progress and result
			if ($onProgressFunc != null) 	_progressBox.push( 	{ workerMethod:$workerMethod, onProgressFunc:$onProgressFunc 	} );
			if ($onResultFunc != null) 		_resultBox.push( 	{ workerMethod:$workerMethod, onResultFunc:$onResultFunc 		} );
			
			$params.unshift($workerMethod);
			try
			{
				_outgoingChannel.send($params);
			}
			catch (err:Error) { };
		}
		
		public function start():void
		{
			_bytes.position = 0;
			_worker = WorkerFactory.getWorkerFromClass(_class, _bytes, _debugMode, null, _giveAppPrivileges, _parseClasses);
			
			_incomingChannel = _worker.createMessageChannel(Worker.current);
			_outgoingChannel = Worker.current.createMessageChannel(_worker);
			
			_worker.setSharedProperty(getQualifiedClassName(_class)+"incoming", _outgoingChannel);
			_worker.setSharedProperty(getQualifiedClassName(_class) + "outgoing", _incomingChannel);
			
			// add listeners
			_worker.addEventListener(Event.WORKER_STATE, onWorkerState);
			_incomingChannel.addEventListener(Event.CHANNEL_MESSAGE, onMessage);
			
			_worker.start();
		}
		
		public function terminate():Boolean
		{
			return _worker.terminate();
		}

// ------------------------------------------------------------------- properties
		
		public function get state():String
		{
			return _worker.state;
		}
	}

}