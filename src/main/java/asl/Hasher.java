package main.java.asl;

import java.util.List;

interface Hasher {

    public abstract Integer getPrimaryMachine(String s);

    public abstract List<Integer> getAllMachines(String s);

}
