#
# Nginx
#

{% set nginx_pkg = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':nginx:pkg', 'nginx') %}

nginx:
  pkg.installed:
    - name: {{nginx_pkg}}
{% if grains.oscodename in ['jessie'] %}
    - fromrepo: {{ grains.oscodename }}-backports
{% endif %}
  service.running:
    - enable: TRUE
    - reload: TRUE
    - require:
      - pkg: nginx
      - file: nginx-cache
    - watch:
      - cmd: nginx-configtest

# generate custom DH parameters
{% if grains['saltversion'] >= '2014.7.0' %}
nginx-dhparam:
  cmd.run:
    - name: openssl dhparam -out /etc/ssl/dhparam.pem 4096
    - creates: /etc/ssl/dhparam.pem
    - require_in:
      - serivce: nginx
{% endif %}

# Add cache directory
nginx-cache:
  file.directory:
    - name: /srv/cache
    - user: www-data
    - group: www-data

# Install meaningful main configuration (SSL tweaks 'n stuff)
/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://nginx/nginx.conf
    - template: jinja
    - watch_in:
      - cmd: nginx-configtest


# Disable default configuration
/etc/nginx/sites-enabled/default:
  file.absent:
    - watch_in:
      - cmd: nginx-configtest

# Install website configuration files configured for this node
{% for website in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':nginx:websites', []) %}
/etc/nginx/sites-enabled/{{website}}:
  file.managed:
    - source: salt://nginx/{{website}}
    - template: jinja
    - require:
      - pkg: nginx
    - watch_in:
      - cmd: nginx-configtest
{% endfor %}

{% if 'frontend' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
  {% for domain, config in pillar.get('frontend', {}).items()|sort %}
    {% if 'file' in config %}
/etc/nginx/sites-enabled/{{domain}}:
  file.managed:
    - source: salt://nginx/{{config.file}}
    - template: jinja
    - require:
      - pkg: nginx
    - watch_in:
      - cmd: nginx-configtest
    {% endif %}
  {% endfor %}

/etc/nginx/sites-enabled/ff-frontend.conf:
  file.managed:
    - source: salt://nginx/ff-frontend.conf
    - template: jinja
    - require:
      - pkg: nginx
    - watch_in:
      - cmd: nginx-configtest
{% endif %}

# Test configuration before reload
nginx-configtest:
  cmd.wait:
    - name: /usr/sbin/nginx -t
