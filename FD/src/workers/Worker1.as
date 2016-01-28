package workers
{
	import com.myflashlabs.utils.worker.WorkerBase;
	
	/**
	 * ...
	 * @author MyFlashLab Team - 1/28/2016 11:00 PM
	 */
	public class Worker1 extends WorkerBase
	{
		
		public function Worker1()
		{
		
		}
		
		// these methods must be public because they are called from the main thread.
		public function forLoop($myParam:int):void
		{
			var thisCommand:Function = arguments.callee;
			
			for (var i:int = 0; i < $myParam; i++)
			{
				// call this method to send progress to your delegate
				sendProgress(thisCommand, i);
			}
			
			// call this method as the final message from the worker. When this is called, you cannot send anymore "sendProgress"
			sendResult(thisCommand, $myParam);
		}
	
	}
}