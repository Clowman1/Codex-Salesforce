public abstract class PersistentObject {
    private PersistenceStrategy.IPersistenceStrategy persistenceStrategy;

    public void setPersistenceStrategy(PersistenceStrategy.IPersistenceStrategy strategy){
        this.persistenceStrategy = strategy;
    }
    protected virtual PersistenceStrategy.IPersistenceStrategy getPersistenceStrategy(){
        return this.persistenceStrategy;
    }
    public abstract void persist();
    public class InvalidTypeException extends Exception{}
}