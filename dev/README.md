# Development

We're using `vagrant` as a tool to simulate executing the ceremony.

## Installation

For arch linux you can use the following command.

```
sudo pacman -S vagrant
```

> Would be awesome if there was some way to use `docker` to standardize on dependencies but I'm not sure what that would look like.

## Basiscs

```
vagrant up        # Starting all nodes (that don't have `autostart: false`
vagrant up <name> # starting an individual box
```

## Working with snapshots

```
vagrant snapshot save <box_name> <snapshot_name>    # Create snapshot
vagrant snapshot restore <box_name> <snapshot_name> # Reverting to a snapshot
```

# Provisioning a box

Anything found in the `<box_name>.vm.provision` section of the `Vagrantfile` will be executed during provisioning.

```
vagrant provision <box_name>
```


## Working with boxes

You can ssh into a vagrant box with the native `vagrant` utility using the following command.

```
vagrant ssh <box_name>
```

Assets are created in the `.ansible` directory.

```
.vagrant/machines/<name>/virtualbox/private_key # secret key
```

# ssh using native ssh rather than vagrant ssh
```
ssh -i .vagrant/machines/<box_name>/virtualbox/private_key vagrant@<ip_address>
```
