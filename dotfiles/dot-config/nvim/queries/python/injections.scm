;; extends
(call
  function: (attribute 
    object: (identifier) @object (#eq? @object "conn")
    attribute: (identifier) @attr (#eq? @attr "execute")) 
  arguments: (argument_list
    (string
      (string_content) @injection.content (#set! injection.language "sql"))))
