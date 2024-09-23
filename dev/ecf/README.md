# Getting Started with ecflow

This README provides a basic guide on how to start using ecflow and load a suite definition file.

## Create the `ecflow` suite
The `ecflow` suite is a collection of tasks that can be run in a specific order.  The suite is defined in a suite definition file, which is a text file that contains the tasks and dependencies between them.
```bash
cd dev/ecf
./setup_ecf.sh
```
This will create a suite definition file called `wafs.def` in the `ecf/def` directory as well as links to the individual forecast hour ecf scripts.

## Starting `ecflow_server`
`ecflow_server` can only be started on dedicated ecflow server nodes.  On WCOSS2, the ecflow server nodes for development are:
- `cdecflow01`, `cdecflow02` (cactus)
- `ddecflow01`, `ddecflow02` (dogwood)

`ssh` to one of the above ecflow server nodes (e.g. `cdecflow01`).
```bash
ssh cdecflow01
```

Before starting the `ecflow_server`, one has to set the following variables.  This only needs to be set once before starting the `ecflow_server`.
```bash
export ECF_ROOT=${HOME}/ecflow
export ECF_OUTPUTDIR=${ECF_ROOT}/output
export LFS_OUTPUTDIR=${ECF_ROOT}/submit
export ECF_COMDIR=${ECF_ROOT}/com
mkdir -p ${ECF_ROOT}
```

You are now ready to start the `ecflow_server`.
```bash
module load ecflow
server_check.sh ${ECF_ROOT}
```
This will start the `ecflow_server` and print out the port number that the server is running on.

`ecflow_server` needs to be started **ONLY** once.  Once the server is running, this window can be closed.
You can now exit the ecflow host where you started the `ecflow_server` and return to the usual WCOSS2 login nodes.

## Starting `ecflow` and loading a Suite Definition File
Load the `ecflow` module on any WCOSS2 login nodes where you want to load the suite definition file.
```bash
module load ecflow
```
This will load `ecflow` in your environment and setup the necessary value for `ECF_PORT`.  It will also add `ecflow` calls to your `PATH`.

Declare `ECF_HOST` on the WCOSS2 login node.  `ECF_HOST` should be the `hostname` on which `ecflow_server` is running.
```bash
export ECF_HOST="cdecflow01"  # This is the hostname on which the `ecflow_server` process is active.
```

Check to ensure the `ecflow_client` can ping the `ecflow_server`:
```bash
ecflow_client --ping
```

If this is successful, one can launch the `ecflow_ui` and place it in the background.
```bash
ecflow_ui &
```

You can use the `ecflow_ui` GUI to start/halt the `ecflow_server`

Navigate to the directory where the suite definition file is located (typically `ecf/def`).
```bash
ecflow_client --load $PWD/wafs.def
```

## Begin Running the Suite
To begin running the suite, use the following command:
```bash
ecflow_client --begin wafs
```

## Some useful commands
`ecflow_client --stats`              To check the status of ecflow_server: HALTED/RUNNING

`ecflow_client --restart`            To start ecflow_server if it is HALTED

`ecflow_client --delete=/yoursuite`  To delete a suite which was previously loaded

`ecflow_stop.sh -p NNNNN`            To stop ecflow_server, where NNNNN is a port number assigned to the ecflow_server

`qstat -u $USER`                     To check any job is running, including triggered by a loaded suite

`ecflow_client --replace=/yoursuite1 $PWD/yoursuite2.def` To load a new suite if not loaded, otherwise replace the suite

## Additional Resources
For more information on using ecflow, refer to the official [documentation](https://ecflow.readthedocs.io/en/latest/overview.html)
