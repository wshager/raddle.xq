xquery version "3.1";

module namespace a="http://raddle.org/array-util";

declare function a:put($array as array(item()?),$position,$member) {
	array:insert-before(array:remove($array, $position),$position,$member)
};

declare function a:fold-left($array as array(item()?),$zero,$function){
	if(array:size($array) eq 0) then
		$zero
	else
		a:fold-left(array:tail($array), $function($zero, array:head($array)), $function )
};

declare function a:fold-left-at($array as array(item()?),$zero,$function) {
	a:fold-left-at($array,$zero,$function,1)
};

declare function a:fold-left-at($array as array(item()?),$zero,$function,$at){
	if(array:size($array) eq 0) then
		$zero
	else
		a:fold-left-at(array:tail($array), $function($zero, array:head($array), $at), $function, $at + 1)
};


declare function a:fold-right-at($array as array(item()?),$zero,$function) {
	a:fold-right-at($array,$zero,$function,1)
};

declare function a:fold-right-at($array as array(item()?),$zero,$function,$at){
	if(array:size($array) eq 0) then
		$zero
	else
		$function( array:head($array), a:fold-right-at(array:tail($array), $zero, $function, $at + 1) )
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
