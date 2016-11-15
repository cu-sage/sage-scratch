/**
 * Created by juliechien on 11/8/16.
 */


package blocks {
import flash.events.*;

public class PointArg extends BlockArg {
    private var spec:String;

    public function PointArg(spec:String, defaultArg:int, menuName:String = '') {
        this.spec = spec;
        var color:int = 0xFFFF00;
        super("n", color, true, menuName);
        field.text = defaultArg.toString();
        base.setColor(0xFFFF00);
        base.redraw();

        field.addEventListener(FocusEvent.FOCUS_OUT, pointArgStopEditing);
        field.addEventListener(Event.CHANGE, textChanged);



    }

    private function pointArgStopEditing(ignore:*):void {
        trace("pointargstopediting called");
//        Specs.pointDict[spec] = 77;

    }

    private function textChanged(evt:*):void {
        trace("pointargtextchanged called");
        argValue = field.text;

        var n:Number = Number(argValue);
        if (!isNaN(n)) {
            /*
            argValue = n;
            if ((field.text.indexOf('.') >= 0) && (argValue is int)) {
                // if text includes a decimal point, make value a float as a signal to
                // primitives (e.g. random) to use real numbers rather than integers.
                // Note: Flash does not appear to distinguish between a floating point
                // value with no fractional part and an int of that value. We mark
                // arguments like 1.0 by adding a tiny epsilon to force them to be a
                // floating point number. Certain primitives, such as random, use
                // this to decide whether to work in integers or real numbers.
                argValue += epsilon;
            }
            */
            Specs.pointDict[spec] = n;

        }


    }
}

}
