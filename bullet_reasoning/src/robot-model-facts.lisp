;;; Copyright (c) 2012, Lorenz Moesenlechner <moesenle@in.tum.de>
;;; All rights reserved.
;;; 
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are met:
;;; 
;;;     * Redistributions of source code must retain the above copyright
;;;       notice, this list of conditions and the following disclaimer.
;;;     * Redistributions in binary form must reproduce the above copyright
;;;       notice, this list of conditions and the following disclaimer in the
;;;       documentation and/or other materials provided with the distribution.
;;;     * Neither the name of the Intelligent Autonomous Systems Group/
;;;       Technische Universitaet Muenchen nor the names of its contributors 
;;;       may be used to endorse or promote products derived from this software 
;;;       without specific prior written permission.
;;; 
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;;; POSSIBILITY OF SUCH DAMAGE.

(in-package :btr)

(def-fact-group robot-model (assert retract)

  (<- (link ?world ?robot-name ?link)
    (bullet-world ?world)
    (%object ?world ?robot-name ?robot)
    (lisp-fun link-names ?robot ?links)
    (member ?link ?links))

  (<- (link-pose ?robot-name ?name ?pose)
    (link-pose ?_ ?robot-name ?name ?pose))

  (<- (link-pose ?w ?robot-name ?name ?pose)
    (bullet-world ?w)
    (%object ?w ?robot-name ?robot)
    (%link-pose ?robot ?name ?pose))

  (<- (%link-pose ?robot ?name ?pose)
    (bound ?robot)
    (bound ?name)
    (lisp-type ?robot robot-object)
    (-> (bound ?pose)
        (and
         (lisp-fun link-pose ?robot ?name ?l-p)
         (poses-equal ?pose ?l-p 0.01 0.01))
        (and
         (lisp-fun link-pose ?robot ?name ?pose)
         (lisp-pred identity ?pose))))

  (<- (%link-pose ?robot ?name ?pose)
    (bound ?robot)
    (not (bound ?name))
    (lisp-type ?robot robot-object)
    (lisp-fun link-names ?robot ?names)
    (member ?name ?names)
    (%link-pose ?robot ?name ?pose))

  (<- (head-pointing-at ?w ?robot-name ?pose)
    (robot ?robot-name)
    (robot-pan-tilt-links ?pan-link ?tilt-link)
    (robot-pan-tilt-joints ?pan-joint ?tilt-joint)
    (bullet-world ?w)
    (%object ?w ?robot-name ?robot)
    (lisp-fun calculate-pan-tilt
              ?robot ?pan-link ?tilt-link ?pose
              (?pan-pos ?tilt-pos))
    (lisp-fun set-joint-state ?robot ?pan-joint ?pan-pos ?_)
    (lisp-fun set-joint-state ?robot ?tilt-joint ?tilt-pos ?_))

  (<- (joint-state ?world ?robot-name ?state)
    (bullet-world ?world)
    (%object ?world ?robot-name ?robot)
    (lisp-fun joint-state ?robot ?state))

  (<- (assert ?world (joint-state ?robot-name ?joint-states))
    (bullet-world ?world)
    (%object ?world ?robot-name ?robot)
    (lisp-fun set-robot-state-from-joints ?joint-states ?robot ?_))

  (<- (assert (joint-state ?world ?robot-name ?joint-states))
    (assert ?world (joint-state ?robot-name ?joint-states)))

  (<- (ik-solution-not-in-collision ?world ?robot-name ?ik-solution)
    (format "in ik-sol coll without grasp~%")
    (bullet-world ?world)
    (with-copied-world ?world
      (assert (joint-state ?world ?robot-name ?ik-solution))
      (object-not-in-collision ?world ?robot-name)))

  ;; this predicate discards contacts with the robot's end-effectors
  ;; as we are grasping an object
  (<- (ik-solution-not-in-collision ?world ?robot-name ?ik-solution :grasping)
    (bullet-world ?world)
    (with-copied-world ?world
      (assert (joint-state ?world ?robot-name ?ik-solution))
      (forall (contact ?world ?robot-name ?object-name ?link)
              (or (attached ?world ?robot-name ?_ ?object-name)
                  (and (slot-value ?world disabled-collision-objects ?objects)
                       (or (member (?robot-name . ?object-name) ?objects)
                           (member (?object-name . ?robot-name) ?objects)))
                  (gripper-link ?_ ?link)))))

  (<- (attached ?world ?robot ?link-name ?object)
    (bullet-world ?world)
    (object ?world ?object)
    (%object ?world ?robot ?robot-instance)
    (%object ?world ?object ?object-instance)
    (lisp-fun object-attached ?robot-instance ?object-instance ?links)
    (member ?link-name ?links))

  (<- (assert ?world (attached ?robot ?link-name ?object))
    (bullet-world ?world)
    (%object ?world ?robot ?robot-instance)
    (lisp-fun attach-object ?robot-instance ?object ?link-name ?_))

  (<- (assert (attached ?world ?robot ?link-name ?object))
    (assert ?world (attached ?robot ?link-name ?object)))

  (<- (retract ?world (attached ?robot ?object))
    (bullet-world ?world)
    (%object ?world ?robot ?robot-instance)
    (lisp-fun detach-object ?robot-instance ?object ?_))

  (<- (retract ?world (attached ?robot ?link-name ?object))
    (bullet-world ?world)
    (%object ?world ?robot ?robot-instance)
    (lisp-fun detach-object ?robot-instance ?object ?link-name ?_))

  (<- (retract (attached ?world . ?rest))
    (retract ?world (attached . ?rest))))
