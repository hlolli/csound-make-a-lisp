;; Start project.csd, then select forms and press Cmd/Ctrl+E.
;; Cmd/Ctrl+Shift+Enter evaluates the whole file.

(ns live)

(def counter (atom 0))
(defn tick! [] (swap! counter inc))

(tick!)
@counter

(->> [1 2 3] (map inc) (reduce +))

;; Define a quiet tone. Evaluate the event to play it.
(csound/definst Tone [hz 440]
  (let [signal (* (csound/poscil 0.03 hz)
                  (csound/linseg 0 0.01 1 (- p3 0.02) 1 0.01 0))]
    (csound/outs signal signal)))

(csound/event "i" Tone 0 0.25 660)

(println "MAL live evaluation is ready" @counter)
