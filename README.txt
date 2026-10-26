# ANSIBLE + GITHUB — DEPLOY LAMP AND SAMBA

**Repository:** https://github.com/manuel-lazarte/aso-first-practice

## 1. Project Description

This project uses Ansible to automate the installation and configuration of services on an openSUSE 16.0 server through SSH.

The project includes Apache, PHP, MariaDB, phpMyAdmin, Samba and previously developed playbooks for FTP.

## 2. Requirements

- Two virtual machines: Ansible Master and Ansible Destination.
- Operating system: openSUSE 16.0.
- Ansible installed on the controller.
- SSH connectivity between both machines.
- Python 3 and the required Ansible collections.
- Administrator privileges on the destination server.

## 3. Project Structure

- `hosts`: Ansible inventory.
- `ansible.cfg`: Ansible configuration.
- `deploy.yml`: Main deployment playbook.
- `roles/apache/`: Apache installation and configuration.
- `roles/php/`: PHP installation and configuration.
- `roles/mariadb/`: MariaDB installation and database configuration.
- `roles/phpmyadmin/`: phpMyAdmin installation.
- `roles/samba/`: Samba installation and shared resource configuration.
- `playbook_ftp.yml`: Previous FTP deployment exercise.

## 4. Steps to Run the Project

1. Clone the GitHub repository:

   `git clone https://github.com/manuel-lazarte/aso-first-practice.git`

2. Enter the project directory:

   `cd aso-first-practice`

3. Check the destination IP address and SSH user in the `hosts` inventory file.

4. Install the required Ansible collections:

   `ansible-galaxy collection install community.mysql`

5. Configure the encrypted variables in `group_vars/all/vault.yml` using Ansible Vault. This file is excluded from the public repository.

6. Verify connectivity:

   `ansible servidor -m ping --ask-vault-pass`

7. Check the deployment syntax:

   `ansible-playbook deploy.yml --syntax-check --ask-vault-pass`

8. Execute the deployment:

   `ansible-playbook deploy.yml -K --ask-vault-pass`

## 5. Verification

The following services were tested successfully in the laboratory:

- Apache: `http://192.168.1.114/`
- PHP: `http://192.168.1.114/prueba.php`
- phpMyAdmin: `http://192.168.1.114/phpMyAdmin/`
- MariaDB: Database `simulacion_db`.
- Samba: Shared directory configured on the destination server.

The IP address corresponds to the laboratory environment and may change in another network.

## 6. Known Limitations

The automatic MariaDB user configuration task still reports an error during the full playbook execution. The database, user permissions and phpMyAdmin access were verified separately.

A fully successful execution of `deploy.yml` on a clean destination machine has not yet been confirmed.

## 7. GitHub

The project includes Ansible scripts, roles and configuration templates.

Repository: https://github.com/manuel-lazarte/aso-first-practice