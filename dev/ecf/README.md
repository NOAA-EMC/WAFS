# Getting Started with ecflow

This README provides a basic guide on how to start using ecflow and load a suite definition file.

## Create the `ecflow` suite
The `ecflow` suite is a collection of tasks that can be run in a specific order.  The suite is defined in a suite definition file, which is a text file that contains the tasks and dependencies between them.
```bash
cd dev/ecf
./setup_ecf.sh
```
This will create a suite definition file called `wafs.def` in the `ecf/def` directory as well as links to the individual forecast hour ecf scripts.

## Loading `ecflow`
`ecflow` can be loaded using the following command:
```bash
module load ecflow
```
This will load `ecflow` in your environment and setup the necessary value for `ECF_PORT`.  It will also add `ecflow` calls to your `PATH`.

## Starting `ecflow_server`
`ecflow_server` can only be started on dedicated ecflow server nodes.  On WCOSS2, the ecflow server nodes for development are:
- `cdecflow01`, `cdecflow02` (cactus)
- `ddcflow01`, `ddcflow02` (dogwood)

Before starting the `ecflow_server`, one has to set the following variables.  This only needs to be set once before starting the `ecflow_server`.
```bash
export ECF_ROOT=${HOME}/ecflow
export ECF_OUTPUTDIR=${ECF_ROOT}/output
export LFS_OUTPUTDIR=${ECF_ROOT}/submit
export ECF_COMDIR=${ECF_ROOT}/com
mkdir -p ${ECF_ROOT}
#server_check.sh ${ECF_ROOT}
```
You are now ready to start the `ecflow_server`.
```bash
server_check.sh ${ECF_ROOT}
```
This will start the `ecflow_server` and print out the port number that the server is running on.

You can now exit the host where you started the `ecflow_server` and return to the usual WCOSS2 login nodes.

## Loading a Suite Definition File
Load the `ecflow` module on the WCOSS2 login node where you want to load the suite definition file.
Check to ensure the `ecflow_client` can ping the `ecflow_server`:
```bash
`ecflow_client --ping`
```

If this is successful, one can launch the `ecflow_ui` and place it in the background.
```bash
ecflow_ui &
```

Navigate to the directory where the suite definition file is located (typically `ecf/def`).
```bash
ecflow_client --load $PWD/wafs.def
```

## Begin Running the Suite
To begin running the suite, use the following command:
```bash
ecflow_client --begin wafs
```

## Additional Resources
For more information on using ecflow, refer to the official [documentation](https://ecflow.readthedocs.io/en/latest/overview.html)
