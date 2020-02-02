package util {
import flash.external.ExternalInterface;

public class Logger {
    public function Logger() {
    }

    public static function logBrowser(message:String,header:String="SCRATCH : "):void{
        try {
            if(ExternalInterface.available){
                ExternalInterface.call("console.log('"+header+message+"')");
            } else {
                trace(message);
            }
        } catch(e:Error) {
            trace(message);
        }
    }

    public static function logAll(message:String):void{
        // trace(message);
        logBrowser(message);
    }

}
}
