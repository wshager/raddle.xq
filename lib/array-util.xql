xquery version "3.1";

module namespace a="http://raddle.org/array-util";
import module namespace console="http://exist-db.org/xquery/console";

declare function a:put($array as array(item()?),$position,$member) {
	array:insert-before(array:remove($array, $position),$position,$member)
};

declare function a:fold-left($array as array(item()?),$zero,$function){
    a:fold-left($array,$zero,$function,array:size($array))
};

declare function a:fold-left($array as array(item()?),$zero,$function, $s){
	if($s eq 0) then
		$zero
	else
		a:fold-left(array:tail($array), $function($zero, array:head($array)), $function, $s - 1)
};

declare function a:fold-left-at($array as array(item()?),$zero,$function) {
	a:fold-left-at($array,$zero,$function,1)
};

declare function a:fold-left-at($array as array(item()?),$zero,$function,$at) {
	a:fold-left-at($array,$zero,$function,$at,array:size($array))
};

declare function a:fold-left-at($array as array(item()?),$zero,$function,$at,$s){
	if($s eq 0) then
		$zero
	else
		a:fold-left-at(array:tail($array), $function($zero, array:head($array), $at), $function, $at + 1, $s - 1)
};

declare function a:fold-right($array as array(item()?),$zero,$function){
    a:fold-right($array, $zero, $function, array:size($array))
};

declare function a:fold-right($array as array(item()?),$zero,$function,$s){
	if($s eq 0) then
		$zero
	else
	    a:fold-right(array:remove($array,$s), $function(array:get($array,$s), $zero), $function, $s - 1)
};

declare function a:fold-right-at($array as array(item()?),$zero,$function) {
	a:fold-right-at($array,$zero,$function,array:size($array))
};

declare function a:fold-right-at($array as array(item()?),$zero,$function,$at){
	if($at eq 0) then
		$zero
	else
	    a:fold-right-at(array:remove($array,$at), $function(array:get($array,$at), $zero, $at), $function, $at - 1)
};

declare function a:for-each($array as array(item()?),$function){
	a:for-each($array,$function,[])
};

declare function a:for-each($array as array(item()?),$function,$ret){
	if(array:size($array) eq 0) then
		$ret
	else
		a:for-each(array:tail($array), $function, array:append($ret,$function(array:head($array))))
};

declare function a:for-each-at($array as array(item()?),$function){
	a:for-each-at($array,$function,[],1)
};

declare function a:for-each-at($array as array(item()?),$function,$ret,$at){
	if(array:size($array) eq 0) then
		$ret
	else
		a:for-each-at(array:tail($array), $function, array:append($ret,$function(array:head($array), $at)), $at + 1)
};

declare function a:last($array as array(item()?)) {
    array:get($array,array:size($array))
};

declare function a:pop($array as array(item()?)) {
    array:remove($array,array:size($array))
};

declare function a:first-index-of($array as array(item()?),$lookup as item()?) {
    a:fold-left-at($array,(),function($pre,$cur,$at) {
        if(empty($pre) or deep-equal($cur, $lookup)) then
            $at
        else
            $pre
    })
};

declare function a:last-index-of($array as array(item()?),$lookup as item()?) {
    a:fold-right-at($array,0,function($cur,$pre,$at) {
        if($pre eq 0 and deep-equal($cur, $lookup)) then
            $at
        else
            $pre
    })
};
