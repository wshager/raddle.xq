xquery version "3.1";

module namespace a="http://raddle.org/array-util";

declare function a:fold-left($array,$zero,$function){
	if(array:size($array) eq 0) then
		$zero
	else
		a:fold-left(array:tail($array), $function($zero, array:head($array)), $function )
};

declare function a:fold-left-at($array,$zero,$function) {
	a:fold-left-at($array,$zero,$function,1)
};

declare function a:fold-left-at($array,$zero,$function,$at){
	if(array:size($array) eq 0) then
		$zero
	else
		a:fold-left-at(array:tail($array), $function($zero, array:head($array), $at), $function, $at + 1)
};

declare function a:for-each($array,$function){
	a:for-each($array,$function,[])
};

declare function a:for-each($array,$function,$ret){
	if(array:size($array) eq 0) then
		$ret
	else
		a:for-each(array:tail($array), $function, array:append($ret,$function(array:head($array))))
};

declare function a:for-each-at($array,$function){
	a:for-each-at($array,$function,[],1)
};

declare function a:for-each-at($array,$function,$ret,$at){
	if(array:size($array) eq 0) then
		$ret
	else
		a:for-each-at(array:tail($array), $function, array:append($ret,$function(array:head($array), $at)), $at + 1)
};
