(* Generated at 2013-05-09 12:56:37.803381+04:00 *)

open QmlContext

external store: cppobj -> < .. > -> unit = "caml_store_value_in_DataItem"

class virtual base_DataItem cppobj = object(self)
  initializer store cppobj self
  method handler = cppobj
  method virtual name: unit-> string
  method virtual sort: unit-> string
end

external create_DataItem: unit -> 'a = "caml_create_DataItem"

