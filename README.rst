ICIS SERVED BY NGINX
==============================

[ICIS][1] is a service that Ister uses to automatically install an instance of Clear Linux via PXE server - equivalent to kickstater files.

What project does?
------------------

Current vagrant project run on CentOS box and run:

- Install uwsgi
- Configure uwsgi service and socket as [one-service-per-app-in-systemd][2]
- Installs nginx
- Configure nginx  web server
- Installs ICIS
- Configure ICIS uwsg app and web service

Run
----

.. code-block:: bash

  $ git clone https://github.com/dlux/vagrant-icis.git
  $ vagrant up

  Open browser on http://localhost:8080/icis

  See message 'Clear Cloud Init Service... is alive'

[1]: https://github.com/clearlinux/ister-cloud-init-svc
[2]: https://uwsgi-docs.readthedocs.io/en/latest/Systemd.html#one-service-per-app-in-systemd

