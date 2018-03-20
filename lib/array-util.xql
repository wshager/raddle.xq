xquery version "3.1";

module namespace a="http://raddle.org/array-util";
(:import module namespace console="http://exist-db.org/xquery/console";:)

declare function a:put($array as array(*),$position,$member) {
    if($position gt array:size($array)) then
        array:append($array,$member)
    else
    	array:insert-before(array:remove($array, $position),$position,$member)
};

declare function a:fold-left($array as array(*),$zero,$function){
    a:fold-left($array,$zero,$function,array:size($array))
};

declare function a:fold-left($array as array(*),$zero,$function, $s){
	if($s eq 0) then
		$zero
	else
		a:fold-left(array:tail($array), $function($zero, array:head($array)), $function, $s - 1)
};

declare function a:fold-left-at($array as array(*),$zero,$function) {
	a:fold-left-at($array,$zero,$function,1)
};

declare function a:fold-left-at($array as array(*),$zero,$function,$at) {
	a:fold-left-at($array,$zero,$function,$at,array:size($array))
};

declare function a:fold-left-at($array as array(*),$zero,$function,$at,$s){
	if($s eq 0) then
		$zero
	else
		a:fold-left-at(array:tail($array), $function($zero, array:head($array), $at), $function, $at + 1, $s - 1)
};


declare function a:reduce-around-at($array,$function) {
    let $head := array:head($array)
	return a:reduce-around-at(array:tail($array),$function,$head,$head,(),2)
};


declare function a:reduce-around-at($array,$function,$zero) {
	a:reduce-around-at($array,$function,$zero,())
};


declare function a:reduce-around-at($array,$function,$zero,$last-seed) {
	a:reduce-around-at($array,$function,$zero,$last-seed,())
};


declare function a:reduce-around-at($array,$function,$zero,$last-seed,$next-seed) {
	a:reduce-around-at($array,$function,$zero,$last-seed,$next-seed,1)
};

declare function a:reduce-around-at($array as array(*),$function as function(item()*,item()*,item()*,item()*,xs:integer) as item()*,$zero,$last-seed,$next-seed,$at as xs:integer) {
    let $tmp := map {
        "out":$zero,
        "last":$last-seed,
        "entry":array:head($array),
        "at":$at
	}
	let $tmp := a:fold-left(array:tail($array),$tmp,function($tmp,$next){
	    let $out := $function($tmp("out"),$tmp("entry"),$tmp("last"),$next,$tmp("at"))
	    let $tmp := map:put($tmp,"out",$out)
	    let $tmp := map:put($tmp,"last",$tmp("entry"))
	    let $tmp := map:put($tmp,"entry",$next)
	    return map:put($tmp,"at",$at + 1)
	})
	return $function($tmp("out"),$tmp("entry"),$tmp("last"),$next-seed,$tmp("at"))
};

declare function a:reduce-ahead-at($array as array(*),$function) {
	a:reduce-ahead-at(array:tail($array),$function,array:head($array),(),2)
};


declare function a:reduce-ahead-at($array as array(*),$function,$zero) {
	a:reduce-ahead-at($array,$function,$zero,())
};


declare function a:reduce-ahead-at($array as array(*),$function,$zero,$next-seed) {
	a:reduce-ahead-at($array,$function,$zero,$next-seed,1)
};

declare function a:reduce-ahead-at($array as array(*),$function as function(item()*,item()*,item()*,xs:integer) as item()*,$zero,$next-seed,$at as xs:integer) {
    let $tmp := map {
        "out":$zero,
        "entry":array:head($array),
        "at":$at
	}
	let $tmp := a:fold-left(array:tail($array),$tmp,function($tmp,$next){
	    let $out := $function($tmp("out"),$tmp("entry"),$next,$tmp("at"))
	    let $tmp := map:put($tmp,"out",$out)
	    let $tmp := map:put($tmp,"entry",$next)
	    return map:put($tmp,"at",$at + 1)
	})
	return $function($tmp("out"),$tmp("entry"),$next-seed,$tmp("at"))
};

declare function a:fold-right($array as array(*),$zero,$function){
    a:fold-right($array, $zero, $function, array:size($array))
};

declare function a:fold-right($array as array(*),$zero,$function,$s){
	if($s eq 0) then
		$zero
	else
	    a:fold-right(array:remove($array,$s), $function($zero,array:get($array,$s)), $function, $s - 1)
};

declare function a:fold-right-at($array as array(*),$zero,$function) {
	a:fold-right-at($array,$zero,$function,array:size($array))
};

declare function a:fold-right-at($array as array(*),$zero,$function,$at){
	if($at eq 0) then
		$zero
	else
	    a:fold-right-at(array:remove($array,$at), $function($zero, array:get($array,$at), $at), $function, $at - 1)
};

declare function a:for-each($array as array(*),$function){
	a:for-each($array,$function,[])
};

declare function a:for-each($array as array(*),$function,$ret){
	if(array:size($array) eq 0) then
		$ret
	else
		a:for-each(array:tail($array), $function, array:append($ret,$function(array:head($array))))
};

declare function a:for-each-at($array as array(*),$function){
	a:for-each-at($array,$function,[],1)
};

declare function a:for-each-at($array as array(*),$function,$ret,$at){
	if(array:size($array) eq 0) then
		$ret
	else
		a:for-each-at(array:tail($array), $function, array:append($ret,$function(array:head($array), $at)), $at + 1)
};

declare function a:last($array as array(*)) {
    array:get($array,array:size($array))
};

declare function a:pop($array as array(*)) {
    array:remove($array,array:size($array))
};

declare function a:first-index-of($array as array(*),$lookup as item()?) {
    a:fold-left-at($array,(),function($pre,$cur,$at) {
        if(empty($pre) or deep-equal($cur, $lookup)) then
            $at
        else
            $pre
    })
};

declare function a:last-index-of($array as array(*),$lookup as item()?) {
    a:fold-right-at($array,0,function($cur,$pre,$at) {
        if($pre eq 0 and deep-equal($cur, $lookup)) then
            $at
        else
            $pre
    })
};
