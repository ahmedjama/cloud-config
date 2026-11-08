# README

```
multipass launch 24.04 \
  --name opencode \
  --cpus 4 \
  --memory 8G \
  --disk 40G \
  --cloud-init cloud-init.yaml
```

```
multipass mount ~/code opencode:/home/ubuntu/workspace
```
