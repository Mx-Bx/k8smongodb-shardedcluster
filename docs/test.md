### Step 1: **Deploy a Test Pod with Networking Tools**

You can run a simple `busybox` or `alpine` pod that includes `telnet` or `curl`. Here’s how to create a test pod:

```bash
kubectl run test-network-a --image=busybox --restart=Never -- sh -c "sleep 3600"
```

### Step 2: **Exec into the Test Pod and Test Connectivity**

Once the pod is running, exec into it and check connectivity from there:

```bash
kubectl exec -it test-network-a -- sh
```

Inside the pod, run the following command to test connectivity to `config-server-2`:

```bash
telnet config-server-2.config-server.default.svc.cluster.local 27201
```

or

```bash
nc -zv config-server-2.config-server.default.svc.cluster.local 27201
```
