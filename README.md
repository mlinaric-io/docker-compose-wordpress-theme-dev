# docker-compose-wordpress-theme-dev

Environment for Wordpress theme development in containers

## Requirements

  - GNU/Linux OS
  - docker (with docker-compose)
  - git config user.name and user.email set

## Usage

```bash
# clone repository
git clone https://github.com/mlinaric-io/docker-compose-wordpress-theme-dev

# make project.sh executable
chmod +x docker-compose-wordpress-theme-dev/project.sh

# rename 'docker-compose-wordpress-theme-dev' to the preferred
# name of our new theme because theme is named after parent
# folder of the project. Default theme name is
# 'docker-compose-wordpress-theme-dev'
mv docker-compose-wordpress-theme-dev newthemename

# go to 'newthemename' and run 'project.sh start'
cd newthemename && ./project.sh start
```

Wordpress site with activated 'newthemename' shall be accessible on 'http://localhost'

## List of services from docker-compose.yml 

- composer
- node
- phpcbf
- phpcs
- phpdoc
- phpmyadmin
- phpunit

## License

docker-compose-wordpress-theme-dev is licensed under [MIT license](LICENSE)
