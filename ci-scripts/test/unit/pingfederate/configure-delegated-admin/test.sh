#!/bin/bash


functionFail() {
  function2() {
    return 1
  }
  function2
}

functionPass() {
  function2() {
    return 0
  }
  function2
}

functionFail
echo "Results $?"

functionPass
echo "Results $?"