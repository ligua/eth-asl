package main.java.asl;

import java.util.List;

interface Hasher {

    /**
     * Get the primary machine for a given key.
     */
    public abstract Integer getPrimaryMachine(String s);

    /**
     * Get all target machines (including primary) we need to write to for a given key.
     */
    public abstract List<Integer> getTargetMachines(Integer primaryMachine);

}
