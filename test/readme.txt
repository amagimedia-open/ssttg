All these tests are to be executed inside bash running inside
the docker (i.e. you need to execute ssttg_run_bash_in_docker.sh
first and then run these tests). This is typically done during 
the development phase.

In host
-------
$ cd .../ssttg
$ ./ssttg_run_bash_in_docker.sh

In docker
---------
# ./test/in/runall.sh
