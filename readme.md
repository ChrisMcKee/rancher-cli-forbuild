# build tools

```shell
docker run --rm -it -v ${PWD}:/app -w /app container-name deploy -e test.env deployment.yml
```

## Additional commands

### Deploy

Does a `kube apply -f` of a deployment and automatically calls wait for rollout to validate the deployment completed.

* Expects variables in the deployment file to be using env style ${MYENVNAME} and will perform a substitution creating an output postfixed file
* Validates the yaml using yq before continuing
* Outputs the contents of the yaml as parsed so it can be reviewed in CI if needed
* Can accept and load in an env var file with line separated key=value of vars to load
* Will validate that all the envs in the file that are there to be replaced have an appropriate field in the current env; outputs any issues

```shell
deploy -e env-file deployment.yml
```

### Smoke 

Uses https://github.com/ChrisMcKee/smoke.sh accessible by calling smoke (added as an executable to bin)
Or load it into your own smoke file as an include as follows

```sh
#!/bin/bash

. /usr/local/bin/smoke

smoke_url_ok "http://google.com/"
    smoke_assert_body "search"
smoke_report
```

There's lots of examples in the readme.
