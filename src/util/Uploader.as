package util {
import flash.events.Event;
import flash.net.URLLoader;
import flash.net.URLLoaderDataFormat;
import flash.net.URLRequest;
import flash.net.URLRequestHeader;
import flash.net.URLRequestMethod;
import flash.utils.ByteArray;

/**
 *
 * Uploader class
 * usage = var uploader:Uploader = new Uploader("http://www.sample.com","picture uploader")
 * uploader.setDataFormat(URLDataFormat.BINARY);
 * uploader.setData(byteArrayData,"picture.jpg")
 * uploader.load()
 * **/

public class Uploader {
    private var name:String; // this more like identity for the uploader instance
    private var url:String;
    private var urlLoader:URLLoader = new URLLoader();
    private var urlRequest:URLRequest;

    public function Uploader(any:*,name:String) {
        // set data
        this.name = name;
        if(any is String){
            this.url = String(any);
            this.urlRequest = new URLRequest(this.url);
        }else if(any is URLRequest){
            this.urlRequest  = any;
        }
        // attach listener
        this.urlLoader.addEventListener(Event.COMPLETE, this.loaderComplete);
        this.urlLoader.addEventListener(Event.OPEN,this.loaderStarted);
        this.urlRequest.method = URLRequestMethod.POST;
        this.urlRequest.contentType = 'multipart/form-data; boundary=' + UploadPostHelper.getBoundary();
        this.urlRequest.requestHeaders.push( new URLRequestHeader( 'Cache-Control', 'no-cache' ) );
    }

    // add handler
    private function loaderStarted(e:Event):void{
        trace(this.name+": upload starting");
    }

    private function loaderComplete(e:Event):void{
        trace(this.name+": upload complete");
    }

    public function upload():Boolean{
        if(this.urlRequest == null){
            return false;
        }
        try{
            this.urlLoader.load(this.urlRequest);
        }catch(err:Error){
            throw err;
        }
        return true;
    }

    public function getURLLoader():URLLoader {
        return urlLoader;
    }

    public function setURLLoader(value:URLLoader):void {
        urlLoader = value;
    }

    public function getURLRequest():URLRequest {
        return urlRequest;
    }

    public function setURLRequest(value:URLRequest):void {
        urlRequest = value;
    }

    public function setData(data:ByteArray,filename:String):void{
        this.urlRequest.data = UploadPostHelper.getPostData(filename,data);
    }
    public function setLoaderDataFormat(dataFormat:String):void{
        this.urlLoader.dataFormat = dataFormat;
    }
}
}
