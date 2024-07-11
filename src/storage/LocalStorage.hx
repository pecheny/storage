package storage;
typedef LocalStorage = 
#if sys
FileStorage
#elseif html5 
BrowserStorage
#else
{}
#end
;