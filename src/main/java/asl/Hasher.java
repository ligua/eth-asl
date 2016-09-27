package main.java.asl;

import java.util.List;

interface Hasher {

    /**
     * Get the primary machine for a given key.
     */
    public abstract Integer getPrimaryMachine(String s);

    /**
     * Get all target machines we need to write to for a given key.
     * The first target machine IS ASSUMED be the primary machine!
     */
    public abstract List<Integer> getTargetMachines(Integer primaryMachine);

}
