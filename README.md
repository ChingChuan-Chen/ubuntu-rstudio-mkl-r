# Dockerfile

A docker of RStudio server with MKL-built R based Ubuntu 20.04.

[Docker Hub](https://hub.docker.com/r/jamal0230/centos-rstudio-mkl-r/)


# Run
1. use `rstudio` as login user with default password:
```
docker run -d -p 8787:8787 --name rstudio jamal0230/centos-rstudio-mkl-r:3.4.4
```

2. use `rstudio` as login user with customized password:
```
docker run -d -p 8787:8787  -e PASSWORD=<password> --name rstudio jamal0230/centos-rstudio-mkl-r:3.4.4
```

3. Customized user and password (it would delete user `rstudio`):
```
docker run -d -p 8787:8787 -e USER=<user> -e PASSWORD=<password> --name rstudio jamal0230/centos-rstudio-mkl-r:3.4.4
```

