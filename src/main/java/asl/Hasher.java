package main.java.asl;

import java.util.List;

interface Hasher {

    /**
     * Get the primary machine for a given key.
     */
    public abstract Integer getPrimaryMachine(String s);

    /**
     * Get all machines we need to write to for a given key.
     */
    public abstract List<Integer> getAllMachines(String s);

}
