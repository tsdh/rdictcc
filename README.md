# RDictCc

RDictCc is a simple translation tool written in Ruby that creates a local
database out of the dictionary files from [dict.cc](http://www.dict.cc).

## Usage

Simply place the file `rdictcc.rb` somewhere in your `PATH`.  Executing
`rdictcc.rb --help` will show you all that's needed.

To make use of the Emacs mode, add this to your `~/.emacs`.

```
;; Adapt path as you need
(add-to-list 'load-path "~/path/to/rdictcc")
(setq rdictcc-program "~/path/to/rdictcc/rdictcc.rb")

(require 'rdictcc)
;; Adapt to your likings
(global-set-key (kbd "C-c t") 'rdictcc-translate-word-at-point)
(global-set-key (kbd "C-c T") 'rdictcc-translate-word)

```

Have fun!

## License

Copyright (C) 2012 Tassilo Horn <tassilo@member.fsf.org>

Distributed under the General Public License, Version 3.
