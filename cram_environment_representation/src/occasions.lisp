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

(in-package :cram-environment-representation)

(def-fact-group occasions (holds)
  (<- (object-in-hand ?object)
    (setof ?object (object-in-hand ?object ?_) ?objects)
    (member ?object ?objects))

  (<- (object-in-hand ?object ?side)
    (bullet-world ?world)
    (robot ?robot)
    (attached ?world ?robot ?link ?object-name)
    (once
     (object-designator-name ?object ?object-name))
    (end-effector-link ?side ?link))

  (<- (object-placed-at ?object ?location)
    (loc ?object ?location))

  (<- (loc plan-knowledge:robot ?location)
    (robot ?robot)
    (object-at-location ?_ ?robot ?location))

  (<- (loc ?object ?location)
    (desig:obj-desig? object)
    (object-designator-name ?object ?object-name)
    (object-at-location ?_ ?object-name ?location))

  (<- (looking-at ?location)
    (fail))

  (<- (object-picked ?object)
    (fail))

  (<- (arms-parked)
    (fail))

  (<- (object-put ?object)
    (fail)))

(def-fact-group occasion-utilities ()
  (<- (object-designator-name ?object-designator ?object-name)
    (or (not (bound ?object-designator))
        (lisp-type ?object-designator desig:object-designator))
    (-> (bound ?object-designator)
        (true)
        (and
         (lisp-fun unique-object-designators ?object-designators)
         (member ?object-designator ?object-designators)))
    (lisp-fun get-designator-object-name ?object-designator
              ?object-name)
    (lisp-pred identity ?object-name))
  
  (<- (object-at-location ?world ?object-name ?location-designator)
    (lisp-type ?location-designator desig:location-designator)
    (bullet-world ?world)
    (lisp-fun desig:current-desig ?location-designator ?current-location)
    (lisp-pred identity ?current-location)
    (desig:desig-solutions ?current-location ?_)
    (or (object-pose ?world ?object-name ?object-pose)
        (object-bottom-pose ?world ?object-name ?object-pose))
    (lisp-pred validate-location ?current-location ?object-pose))

  (<- (object-at-location ?world ?object-name ?location-designator)
    (not (bound ?location))
    (bullet-world ?world)
    (object-pose ?world ?object-name ?object-pose)
    (desig:designator desig:location ((pose ?object-pose))
                      ?location-designator)))

(defun unique-object-designators ()
  "Returns all designators. For equated designators, only one instance
is returned."
  (remove-duplicates
   (remove-if-not (lambda (designator)
                    (and
                     (typep designator 'desig:object-designator)))
                  (reverse (desig:get-all-designators)))
   :test #'desig:desig-equal))

(defmethod cram-plan-knowledge:clear-belief cram-environment-representation ()
  (setf *current-bullet-world* (make-instance 'bt-reasoning-world))
  (setup-world-database)
  (set-robot-state-from-tf
   cram-roslisp-common:*tf2-buffer*
   (var-value '?robot-instance (lazy-car (prolog `(and (robot ?robot)
                                                       (%object ?_ ?robot ?robot-instance)))))))

(defvar *robot-urdf* nil)
(defvar *kitchen-urdf* nil)

(defun setup-world-database ()
  (let ((robot (or *robot-urdf*
                   (setf *robot-urdf*
                         (cl-urdf:parse-urdf
                          (roslisp:get-param "robot_description_lowres")))))
        (kitchen (or *kitchen-urdf*
                     (let ((kitchen-urdf-string
                             (roslisp:get-param "kitchen_description" nil)))
                       (when kitchen-urdf-string
                         (setf *kitchen-urdf* (cl-urdf:parse-urdf
                                               kitchen-urdf-string)))))))
    (assert
     (force-ll (prolog `(and
                         (bullet-world ?w)
                         (assert ?w (object static-plane floor ((0 0 0) (0 0 0 1))
                                            :normal (0 0 1) :constant 0))
                         (assert ?w (object semantic-map sem-map ((0 0 0) (0 0 0 1))
                                            ,@(when kitchen
                                                `(:urdf ,kitchen))))
                         (robot ?robot)
                         (assert ?w (object urdf ?robot ((0 0 0) (0 0 0 1)) :urdf ,robot))))))))
