#! /bin/bash

if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "docker-compose-wordpress-theme-dev runs only on GNU/Linux operating system. Exiting..."
  exit
fi

###############################################################################
# 1.) Assign variables and create directory structure
###############################################################################

  #PROJECT_NAME is parent directory
  PROJECT_NAME=`echo ${PWD##*/}`
  PROJECT_UID=`id -u`
  PROJECT_GID=`id -g`

  PROJECT_AUTHOR=`git config user.name`
  if [ -z "${PROJECT_AUTHOR}" ]; then 
    echo "ALERT: git config user.name is not set!"
    exit
  fi
    
  PROJECT_EMAIL=`git config user.email`
  if [ -z "${PROJECT_EMAIL}" ]; then 
    echo "ALERT: git config user.email is not set!"
    exit
  fi
  
############################ CLEAN SUBROUTINE #################################

clean() {
  docker-compose stop
  docker system prune -af --volumes
  rm -rf node_modules \
      vendor \
      .cache \
      .config \
      .phpunit.cache \
      .yarn
} 

############################ START SUBROUTINE #################################

start() {
  
  mkdir -p tests/{spec,phpunit} \
    docs

###############################################################################
# 2.) Generate very basic theme if it doesn't exist
###############################################################################

  if [[ ! -d $PROJECT_NAME ]]; then

    # generate .git folder with initial commit
    rm -rf .git
    git init
    git add .
    git commit -m "feat: initial commit"

    # generate theme files
    mkdir -p $PROJECT_NAME/{assets,framework,languages,layouts}
    mkdir -p $PROJECT_NAME/assets/{js,src}
    
    touch $PROJECT_NAME/index.php
    cat <<EOF> $PROJECT_NAME/index.php
<?php
/**
 * PHP Version 7
 * 
 * @package  $PROJECT_NAME
 * @author   $PROJECT_AUTHOR <$PROJECT_EMAIL>
 * @license  GNU General Public License v2 or later http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
 */

get_header();

if (have_posts() ) : 
    while ( have_posts() ) : the_post(); ?> 
        <li id="post-<?php the_ID(); ?>" 
        <?php post_class('stm_post_info'); ?>>
        <?php if(get_the_title() ) : ?>
        <h4 class="stripe_2"><a href="<?php echo get_permalink(\$post->ID); ?>">
            <?php the_title(); ?></a></h4>
            <?php 
        endif;
        the_content();
    endwhile;
else :
    _e('Sorry, no posts matched your criteria.', 'textdomain');
endif;


get_footer();

EOF

    touch $PROJECT_NAME/functions.php
    cat <<EOF> $PROJECT_NAME/functions.php
<?php
/**
 * PHP Version 7
 * 
 * @package  $PROJECT_NAME
 * @author   $PROJECT_AUTHOR <$PROJECT_EMAIL>
 * @license  GNU General Public License v2 or later http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
 */

/**
 * Enqueue scripts and styles.
 *
 * @return void
 */
function basic_scripts() 
{
    wp_enqueue_style( 
        'project-style', 
        get_template_directory_uri() . '/style.css', 
        array(), 
        wp_get_theme()->get('Version') 
    );
}

add_action('wp_enqueue_scripts', 'basic_scripts');

EOF

    touch $PROJECT_NAME/style.css
    cat <<EOF> $PROJECT_NAME/style.css
/*
 * Theme Name:  $PROJECT_NAME
 * Theme DIR:
 * Description: $PROJECT_NAME theme
 * Version:     1.0.0
 * Author:      $PROJECT_AUTHOR <$PROJECT_EMAIL>
 * Author DIR:
 * Tags:        custom-header, custom-menu, featured-images, post-formats, sticky-post
 * License:     GNU General Public License v2 or later
 * License DIR: http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
 * Text Domain: $PROJECT_NAME
 */

* {
    margin: 0;
    padding: 0;
}

body, html {

}

EOF
  fi


###############################################################################
# 2.) Generate configuration files
###############################################################################

  if [[ ! -f docker-compose.yml ]]; then
    touch docker-compose.yml
    cat <<EOF>docker-compose.yml
    version: "3.8"

    services:
      database:
        image: mariadb:latest
        volumes:
          - db_data:/var/lib/mysql
        environment:
          MYSQL_ROOT_PASSWORD: $PROJECT_NAME
          MYSQL_DATABASE:      $PROJECT_NAME
          MYSQL_USER:          $PROJECT_NAME
          MYSQL_PASSWORD:      $PROJECT_NAME

      wordpress:
        image: wordpress:latest
        user: $PROJECT_UID:$PROJECT_GID
        volumes:
          - ./$PROJECT_NAME:/var/www/html/wp-content/themes/$PROJECT_NAME
        links:
          - database
        ports:
          - 80:80
        environment:
          WORDPRESS_DB_HOST:     database
          WORDPRESS_DB_USER:     $PROJECT_NAME
          WORDPRESS_DB_PASSWORD: $PROJECT_NAME
          WORDPRESS_DB_NAME:     $PROJECT_NAME

      wpcli:
        image: wordpress:cli
        user: $PROJECT_UID:$PROJECT_GID
        command: >
          /bin/sh -c '
          wp core install --path="/var/www/html" --url="http://localhost" --title="Testing Site" --admin_user="$PROJECT_NAME" --admin_password="$PROJECT_NAME" --admin_email=foo@bar.com --skip-email;
          '
        links:
          - wordpress
        volumes_from:
          - wordpress
        environment:
          WORDPRESS_DB_HOST:     database
          WORDPRESS_DB_USER:     $PROJECT_NAME
          WORDPRESS_DB_PASSWORD: $PROJECT_NAME
          WORDPRESS_DB_NAME:     $PROJECT_NAME

      composer:
        image: composer:latest
        user: $PROJECT_UID:$PROJECT_GID
        command: [ composer, install ]
        volumes:
          - .:/app
        environment:
          - COMPOSER_CACHE_DIR=/var/cache/composer

      node:
        image: node:16-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /home/node
        volumes:
          - .:/home/node
        environment:
          NODE_ENV: development

      phpcbf:
        image: php:7.4-fpm-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /app
        volumes:
          - .:/app
        entrypoint: vendor/bin/phpcbf

      phpcs:
        image: php:7.4-fpm-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /app
        volumes:
          - .:/app
        entrypoint: vendor/bin/phpcs

      phpdoc:
        image: phpdoc/phpdoc
        user: $PROJECT_UID:$PROJECT_GID
        volumes:
          - .:/data

      phpmyadmin:
        image: phpmyadmin/phpmyadmin
        environment:
          PMA_HOST: database
          PMA_PORT: 3306
          MYSQL_ROOT_PASSWORD: $PROJECT_NAME
        ports:
          - 8080:80

      phpunit:
        image: php:7.4-fpm-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /app
        volumes:
          - .:/app
        entrypoint: vendor/bin/phpunit


    volumes:
      db_data:
EOF
  fi

  if [[ ! -f phpunit.xml ]]; then
    touch phpunit.xml
    cat <<EOF> phpunit.xml
<?xml version="1.0" encoding="UTF-8"?>
  <phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
           xsi:noNamespaceSchemaLocation="https://schema.phpunit.de/9.5/phpunit.xsd"
           bootstrap="./vendor/autoload.php"
           cacheResultFile=".phpunit.cache/test-results"
           executionOrder="depends,defects"
           forceCoversAnnotation="true"
           beStrictAboutCoversAnnotation="true"
           beStrictAboutOutputDuringTests="true"
           beStrictAboutTodoAnnotatedTests="true"
           convertDeprecationsToExceptions="true"
           failOnRisky="true"
           failOnWarning="true"
           verbose="true">
      <testsuites>
          <testsuite name="default">
              <directory>./tests/phpunit</directory>
          </testsuite>
      </testsuites>

      <coverage cacheDirectory=".phpunit.cache/code-coverage"
                processUncoveredFiles="true">
          <include>
              <directory suffix=".php">./$PROJECT_NAME</directory>
          </include>
      </coverage>
  </phpunit>
EOF
  fi

  if [[ ! -f phpcs.xml ]]; then
    touch phpcs.xml
    cat <<EOF> phpcs.xml
<?xml version="1.0"?>
  <ruleset xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
  name="$PROJECT_NAME" 
  xsi:noNamespaceSchemaLocation="https://raw.githubusercontent.com/squizlabs/PHP_CodeSniffer/master/phpcs.xsd">
  
    <file>$PROJECT_NAME/</file>
    <file>tests/</file>
       
    <exclude-pattern>*\.(scss|css|js)$</exclude-pattern>    
    
    <rule ref="WordPress">
    </rule>
    
  </ruleset>
EOF
  fi

  if [[ ! -f .gitignore ]]; then
    touch .gitignore
    cat <<EOF> .gitignore
# Ignore docs folder
/docs/

# Ignore node_modules folder
/node_modules/

# Ignore vendor folder
/vendor/

# Ignore .cache folder
/.cache/

# Ignore .config folder
/.config/

# Ignore .phpunit.cache folder
/.phpunit.cache/

# Ignore .yarn folder
/.yarn/

# Ignore .lock files
*.lock
EOF
  fi

    if [[ ! -f composer.json ]]; then
    touch composer.json
    cat <<EOF> composer.json
{
    "name": "$PROJECT_AUTHOR/$PROJECT_NAME",
    "description": "docker-compose-wordpress-theme-dev project",
    "version": "1.0.0",
    "type": "wordpress-theme",
    "license": "GPL-2.0-or-later",
    "authors": [
      {
        "name": "$PROJECT_AUTHOR",
        "email": "$PROJECT_EMAIL"
      }
    ],
    "autoload": {
      "psr-4": { "": "$PROJECT_NAME/"}
    }
}
EOF
  fi

    if [[ ! -f package.json ]]; then
    touch package.json
    cat <<EOF> package.json
{
    "name": "$PROJECT_NAME",
    "description": "docker-compose-wordpress-theme-dev project",
    "version": "1.0.0",
    "license": "GPL-2.0-or-later",
    "author": "$PROJECT_AUTHOR <$PROJECT_EMAIL>",
    "private": true
}
EOF
  fi

###############################################################################
# 3.) Install dependencies
###############################################################################

#PHP

  docker-compose run composer
  docker-compose run composer composer require --dev phpunit/phpunit
  docker-compose run composer composer require --dev squizlabs/php_codesniffer
  docker-compose run composer composer require --dev wp-coding-standards/wpcs
  docker-compose run composer config allow-plugins.dealerdirect/phpcodesniffer-composer-installer  true
  docker-compose run composer composer require --dev dealerdirect/phpcodesniffer-composer-installer
  docker-compose run composer -- dump-autoload

#JavaScript

  docker-compose run node yarn install
  docker-compose run node yarn global add ynpx
  docker-compose run node yarn add -D @wordpress/scripts

  docker-compose up -d
  sleep 10

# Activate theme

  docker-compose run wpcli && \
  docker-compose run wpcli wp theme activate $PROJECT_NAME

}

"$1"
