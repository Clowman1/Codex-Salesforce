global abstract class PersistenceStrategy implements IPersistenceStrategy{
    global interface IPersistenceStrategy{
        void persist(SObject data);
    }
    public virtual void persist(SObject data){
        if(data.Id == null){
            insert data; 
        }else{
            update data;
        }
    }
    public class BasicSave extends PersistenceStrategy{}

    public class BulkifiedSave extends PersistenceStrategy{
        private List<SObject> updateObjects=new List<SObject>();
        private List<SObject> insertObjects= new List<SObject>();
        public List<Database.SaveResult> flush(){
            List<Database.SaveResult> saveResults = new List<Database.SaveResult>();
            if(this.insertObjects.size()>0){
                saveResults.addAll(Database.insert(this.insertObjects));
            }
            if(this.updateObjects.size()>0){
                saveResults.addAll(Database.update(this.updateObjects));
            }
            return saveResults;
        }
        public override void persist(SObject data){
            if(data.Id == null){
                this.insertObjects.add(data);
            }else{
                this.updateObjects.add(data);
            }
        }
    }
}