{
  /*
    Run a python function on all nodes in the cluster.
    The function takes one argument, a function with one argument which is the node's name.
  */
  runOnAllNodes = f: ''
    for node in cluster.nodes:
      with subtest(node.name):
        ${f "node.name"}
  '';
}
