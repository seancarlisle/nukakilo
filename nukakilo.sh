#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script I wrote to blow away a Kilo environment in order to test             #
# Upgrades from Juno to Kilo.                                                 #
#                                                                             #
# Please note this script makes a lot of assumptions about things base on     #
# this environment, so you may not want to run it elsewhere...                #
#                                                                             #
###############################################################################

###############################################################################
#                                                                             #
# Helper functions.                                                           #
#                                                                             #
###############################################################################

# Uses ansible to remotely delete all project files
function ansible_delete_files {
   PROJECT=$1
   ANSIBLE_GROUP=$2

   cd /opt/openstack-ansible/playbooks

   echo "Deleting all $PROJECT files"
   /usr/local/bin/ansible $ANSIBLE_GROUP -m shell -a "for item in \$(find / -name $PROJECT*);do rm -rf \$item;done"
 
   return 0

}

# Uses ansible to remotely stop all services on bare metal
function ansible_stop_services {
   PROJECT=$1
   ANSIBLE_GROUP=$2

   cd /opt/openstack-ansible/playbooks

   echo "Stopping all $PROJECT services"
   /usr/local/bin/ansible $ANSIBLE_GROUP -m shell -a "for srv in \$(ls /etc/init/$PROJECT* | awk -F\/ '{print \$4}' | cut -d\. -f1);do service \$srv stop;done"

   return 0

}

# Uses ansible to remotely uninstall all pip packages and clean up the mess left behind
function ansible_pip_delete {
   ANSIBLE_GROUP=$1

   cd /opt/openstack-ansible/playbooks

   echo "Uninstalling all pip packages"
   /usr/local/bin/ansible $ANSIBLE_GROUP -m shell -a "for pkg in \$(pip list | awk -F\( '{print \$1}');do pip uninstall -y \$pkg;done"

   # Clean up after the removal (cause stuff will get left behind...)
   echo "Clean up after the removal (cause stuff will get left behind...)"
   /usr/local/bin/ansible $ANSIBLE_GROUP -m shell -a "rm -rf /usr/local/lib/python2.7/dist-packages/*"
   /usr/local/bin/ansible $ANSIBLE_GROUP -m shell -a "rm -rf /usr/lib/python2.7/dist-packages/*"

   return 0

}

# Uses ansible to remotely remove lxc_trusty.tgz and the lxc cache itself
function ansible_delete_cache {

   ANSIBLE_GROUP=$1

   cd /opt/openstack-ansible/playbooks

   echo "Remove lxc_trusty.tgz and the lxc cache itself"
   /usr/local/bin/ansible $ANSIBLE_GROUP -m shell -a "rm -rf /var/cache/lxc_trusty.tgz;rm -rf /var/cache/lxc/*"

   return 0

}

# Uses ansible to remotely destroy all containers
function ansible_destroy_containers {
   ANSIBLE_GROUP=$1

   cd /opt/openstack-ansible/playbooks

   /usr/local/bin/ansible $ANSIBLE_GROUP -m shell -a "for container in \$(lxc-ls);do lxc-destroy -f -n \$container;done"

   return 0

}

# Uses ansible to remotely destroy /openstack
function ansible_delete_openstack_dir {
   ANSIBLE_GROUP=$1

   cd /opt/openstack-ansible/playbooks

   /usr/local/bin/ansible $ANSIBLE_GROUP -m shell -a "rm -rf /openstack/*"

   return 0

}




###############################################################################
#                                                                             #
# Functions to do all the heavy lifting.                                      #
#                                                                             #
###############################################################################

# Destroys all installation info and data on swift object nodes
function nuka_swift {
   
   # Stop all swift services
   ansible_stop_services swift swift_hosts

   # Delete all swift files
   ansible_delete_files swift swift_hosts

   # Remove all pip packages
   ansible_pip_delete swift_hosts

   # Remove lxc_trusty.tgz and the lxc cache itself
   ansible_delete_cache swift_hosts

   # Delete all in /openstack
   ansible_delete_openstack_dir swift_hosts

   # Destroy swift proxy containers
   #echo "Destroy swift proxy containers"
   #/usr/local/bin/ansible swift-proxy_hosts -m shell -a "for container in \$(lxc-ls | grep swift);do lxc-destroy -f -n \$container;done"

   return 0
}

# Destroys all installation info and data on nova computes
function nuka_compute {

   # Stop nova-compute services
   #echo "Stop nova-compute services"
   #/usr/local/bin/ansible nova_compute -m service -a "name=nova-compute state=stopped"
   ansible_stop_services nova nova_compute

   # Stop neutron services
   #echo "Stop neutron services"
   #/usr/local/bin/ansible nova_compute -m service -a "name=neutron-linuxbridge-agent state=stopped"
   ansible_stop_services neutron nova_compute

   # Delete all nova files
   #echo "Delete all nova files"
   #/usr/local/bin/ansible nova_compute -m shell -a "for item in \$(find / -name nova*);do rm -rf \$item;done"
   ansible_delete_files nova nova_compute

   # Delete all neutron files
   #echo "Delete all neutron files"
   #/usr/local/bin/ansible nova_compute -m shell -a "for item in \$(find / -name neutron*);do rm -rf \$item;done"
   ansible delete_files neutron nova_compute

   # Remove all pip packages
   #echo "Remove all pip packages"
   #/usr/local/bin/ansible nova_compute -m shell -a "for pkg in \$(pip list | awk -F\( '{print \$1}');do pip uninstall -y \$pkg;done"
   ansible_pip_delete nova_compute

   # Clean up after the removal (cause stuff will get left behind...)
   #echo "Clean up after the removal (cause stuff will get left behind...)"
   #/usr/local/bin/ansible nova_compute -m shell -a "rm -rf /usr/local/lib/python2.7/dist-packages/*"
   #/usr/local/bin/ansible nova_compute -m shell -a "rm -rf /usr/lib/python2.7/dist-packages/*"

   # Remove lxc_trusty.tgz and the lxc cache itself
   #echo "Remove lxc_trusty.tgz and the lxc cache itself"
   #/usr/local/bin/ansible nova_compute -m shell -a "rm -rf /var/cache/lxc_trusty.tgz;rm -rf /var/cache/lxc/*"
   ansible_delete_cache nova_compute
   
   # Delete all in /openstack
   #echo "Delete all in /openstack"
   #/usr/local/bin/ansible nova_compute -m shell -a "rm -rf /openstack/*"
   ansible_delete_openstack_dir nova_compute

   return 0
}

# Destroys all installation info and data on cinder storage nodes
function nuka_cinder {

   METAL=$1
   cd /opt/openstack-ansible/playbooks

   if [ "$METAL" == "true" ]
   then

      # Ensure all stray volumes were destroyed
      /usr/local/bin/ansible storage_hosts -m shell -a "for vol in \$(lvs cinder-volumes);do lvremove -f \$vol;done"

      # Stop all cinder services
      #/usr/local/bin/ansible storage_hosts -m shell -a "for srv in \$(ls /etc/init/cinder* | awk -F\/ '{print \$4}' | cut -d\. -f1);do service \$srv stop;done"

      # Delete all cinder files
      #/usr/local/bin/ansible storage_hosts -m shell -a "for item in \$(find / -name cinder*);do rm -rf \$item;done"

      # Stop all cinder services
      ansible_stop_services storage_hosts cinder

      # Delete all cinder files
      ansible__delete_files storage_hosts cinder

   else
      
      # Ensure all stray volumes were destroyed
      /usr/local/bin/ansible cinder_volume -m shell -a "for vol in \$(lvs cinder-volumes);do lvremove -f \$vol;done"

      # Destroy the cinder containers
      #/usr/local/bin/ansible storage_hosts -m shell -a "for container in \$(lxc-ls);do lxc-destroy -f -n \$container;done"
      ansible_destroy_containers storage_hosts
      
   fi
   
   # Remove all pip packages
   #/usr/local/bin/ansible storage_hosts -m shell -a "for pkg in \$(pip list | awk -F\( '{print \$1}');do pip uninstall -y \$pkg;done"
   ansible_pip_delete storage_hosts

   # Clean up after the removal (cause stuff will get left behind...)
   #/usr/local/bin/ansible storage_hosts -m shell -a "rm -rf /usr/local/lib/python2.7/dist-packages/*"
   #/usr/local/bin/ansible storage_hosts -m shell -a "rm -rf /usr/lib/python2.7/dist-packages/*"

   # Remove lxc_trusty.tgz and the lxc cache itself
   #/usr/local/bin/ansible storage_hosts -m shell -a "rm -rf /var/cache/lxc_trusty.tgz;rm -rf /var/cache/lxc/*"
   ansible_delete_cache storage_hosts

   # Delete all in /openstack
   #/usr/local/bin/ansible storage_hosts -m shell -a "rm -rf /openstack/*"
   ansible_delete_openstack_dir storage_hosts

   return 0
}

# Destroys all installation info and data on the logger node
function nuka_logger {

   cd /opt/openstack-ansible/playbooks

   # Destroy all containers
   #/usr/local/bin/ansible log_hosts -m shell -a "for container in \$(lxc-ls);do lxc-destroy -f -n \$container;done"
   ansible_destroy_containers log_hosts

   # Delete all in /openstack
   #/usr/local/bin/ansible log_hosts -m shell -a "rm -rf /openstack/*"   
   ansible_delete_openstack_dir log_hosts

   # Remove lxc_trusty.tgz and the lxc cache itself
   #/usr/local/bin/ansible log_hosts -m shell -a "rm -rf /var/cache/lxc_trusty.tgz;rm -rf /var/cache/lxc/*"
   ansible_delete_cache log_hosts

   # Uninstall all pip packages
   #/usr/local/bin/ansible log_hosts -m shell -a "for pkg in \$(pip list | awk -F\( '{print \$1}');do pip uninstall -y \$pkg;done"
   ansible_pip_delete log_hosts

   # Clean up after the removal (cause stuff will get left behind...)
   #/usr/local/bin/ansible log_hosts -m shell -a "rm -rf /usr/local/lib/python2.7/dist-packages/*"
   #/usr/local/bin/ansible log_hosts -m shell -a "rm -rf /usr/lib/python2.7/dist-packages/*"

   return 0
}

# Destroys all installation info and data on the infra nodes
function nuka_infra {
   
   INFRAS=$1   
   cd /opt/openstack-ansible/playbooks


   # Destroy all containers
   /usr/local/bin/ansible infra_hosts -m shell -a "for container in \$(lxc-ls);do lxc-destroy -f -n \$container;done"

   # Delete all in /openstack
   /usr/local/bin/ansible infra_hosts -m shell -a "rm -rf /openstack/*"   
 
   # Remove lxc_trusty.tgz and the lxc cache itself
   /usr/local/bin/ansible infra_hosts -m shell -a "rm -rf /var/cache/lxc_trusty.tgz;rm -rf /var/cache/lxc/*"

   for infra in ${INFRAS[@]}
   do
      if [ "$infra" != *"infra01"* ]
      then

         # ssh to infra and delete all the things
         ssh $infra "for pkg in \$(pip list | awk -F\( '{print \$1}');do pip uninstall -y \$pkg;done"

         # Clean up after the removal (cause stuff will get left behind...)
         ssh $infra "rm -rf /usr/local/lib/python2.7/dist-packages/*"
         ssh $infra  "rm -rf /usr/lib/python2.7/dist-packages/*"

         # Delete the binaries that were placed on the infra
         ssh $infra "for srv in nova neutron cinder heat keystone openstack glance swift;do rm /usr/local/bin/\$srv*"

      fi
   done

   # Delete all the things on infra01
   for pkg in $(pip list | awk -F\( '{print $1}')
   do
      pip uninstall -y $pkg
   done

   # Clean up after the removal (cause stuff will get left behind...)
   rm -rf /usr/local/lib/python2.7/dist-packages/*
   rm -rf /usr/lib/python2.7/dist-packages/*

   # Delete the binaries that were placed on the infra
   for srv in nova neutron cinder heat keystone openstack glance swift
   do 
      rm /usr/local/bin/$srv*
   done

  # Delete the playbooks
  rm -rf /opt/openstack-ansible
  rm -rf /opt/rpc-openstack

  # Delete the environment info
  rm -rf /etc/openstack_deploy
  #rm -rf /etc/rpc_deploy.OLD

   return 0
}



########################################################
#                                                      #
# Main                                                 #
#                                                      #
########################################################


read -p "Have all instances been deleted? (yes|no)" DELETED

if [ "$DELETED" != "yes" ]
then
   echo "Delete all instances and then rerun this script.  Exiting..."
   exit 0
fi

read -p "Have all volumes been deleted? (yes|no)" DELETED

if [ "$DELETED" != "yes" ]
then
   echo "Delete all volumes and then rerun this script.  Exiting..."
   exit 0
fi

read -p "Have all images been deleted? (yes|no)" DELETED

if [ "$DELETED" != "yes" ]
then
   echo "Delete all images and then rerun this script.  Exiting..."
   exit 0
fi

echo "Let's get started..."

grep swift /etc/openstack_deploy/openstack_inventory.json &> /dev/null
if [ $? -eq 0 ]
then
   echo "Swift detected.  Nuking swift..."
   nuka_swift
   echo "Done"
fi

echo "Nuking Cinder..."

grep cinder_volume_container /etc/openstack_deploy/openstack_inventory.json &> /dev/null
if [ $? -eq 0 ]
then
   nuka_cinder "false"
else
   nuka_cinder "true"
fi
echo "Done"

echo "Nuking Compute..."
nuka_compute
echo "Done"

echo "Nuking Logger..."
nuka_logger
echo "Done"

echo "Nuking infras..."
# Getting the infras
INFRAS=()

for infra in $(grep -A4 '"infra_hosts": {' /etc/openstack_deploy/openstack_inventory.json | grep -v hosts | tr -d ' ,"' | sort)
do 
   INFRAS=( "${INFRAS[@]}" "$infra" )
done

echo ${INFRAS[@]}
nuka_infra $INFRAS

echo "We're done here."
