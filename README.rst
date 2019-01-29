ICIS on CentOS and NGINX
========================

.. image:: https://travis-ci.com/dlux/vagrant-icis.svg?branch=master
    :target: https://travis-ci.com/dlux/vagrant-icis


`ICIS <https://github.com/clearlinux/ister-cloud-init-svc>`_ is a service that Ister uses to automatically install an instance of Clear Linux via PXE server - equivalent to kickstart files.

What project does?
------------------

Current vagrant project run on CentOS box and do:

- Install uwsgi
- Configure uwsgi service and socket as `one-service-per-app-in-systemd <https://uwsgi-docs.readthedocs.io/en/latest/Systemd.html#one-service-per-app-in-systemd>`_
- Installs nginx
- Configure nginx  web server
- Installs ICIS
- Configure ICIS uwsg app and web service

To Run
------

.. code-block:: bash

  $ git clone https://github.com/dlux/vagrant-icis.git
  $ vagrant up

  Open browser on http://localhost:8080/icis

  See message 'Clear Cloud Init Service... is alive'

