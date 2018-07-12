/**
  LinkedIn Registration Handler
**/
global class LinkedInRegistrationHandler implements Auth.RegistrationHandler {

    /**
     * Required supplied fields email, lastName, firstName
     *
     * @data - the user's info from the Auth Provider
    **/
    global boolean canCreateUser(Auth.UserData data) {
        System.debug('canCreateUser was called for ' + (data != null ? data.email : 'null'));
        Boolean retVal = (data != null
                && data.email != null
                && data.lastName != null
                && data.firstName != null);

        System.debug('data.username=' + data.username);
        System.debug('data.email=' + data.email);
        System.debug('data.lastName=' + data.lastName);
        System.debug('data.firstName=' + data.firstName);

        return retVal;
    }

    /**
     * Create the User - A required method to implement the Handler Interface
     *
     * @param portalId  - Id of the Community
     * @param data - Auth Provider user data describing the User to create
     *
     * @return User that has been initialized
    **/
    global User createUser(Id portalId, Auth.UserData data) {
        if (!canCreateUser(data)) {
            return null;
        }

        /**
         * Check is this a Community Context
         * This check will be necessary if there is an opportunity
         * to be registered not only in the community, but also on the internal portal
        **/
        if (data.attributeMap.containsKey('sfdc_networkid')) {
            System.debug('Registering Community user: ' + data.email);
            Id contactId;

            // Checking to see if the email address is already used by another Contact
            List<Contact> existingContacts = [
                    select id, email
                    from Contact
                    where email = :data.email
            ];
            if (existingContacts.size() > 0) {
                Contact existingContact = existingContacts[0];
                contactId = existingContact.Id;
                List<User> existingUsers = [
                        select id
                        from User
                        where ContactId = :contactId
                ];
                if (existingUsers.size() == 1) {
                    return existingUsers[0];
                }
            } else {
                contactId = createContact(data);
                System.debug('Created contact: ' + contactId);
            }

            Profile p = [
                    SELECT Id
                    FROM profile
                    WHERE name = :Registration_Handler_Settings__c.getValues('LinkedIn').External_User_Profile__c
            ];
            System.debug('Found profile: ' + p);

            User u = createUser(data, p);

            u.contactId = contactId;
            return u;
        } else {
            //This is not a community, so we Assign an internal profile
            Profile p = [
                    SELECT Id
                    FROM profile
                    WHERE name = :Registration_Handler_Settings__c.getValues('LinkedIn').Internal_User_Profile__c
            ];
            System.debug('Found profile: ' + p);

            User u = createUser(data, p);

            return u;
        }
    }

    /**
     * Update the user - A required method to implement the Handler Interface
     *
     * @param portalId  - Id of the Community
     * @param data - Auth Provider user data describing the User to create
    **/
    global void updateUser(Id userId, Id portalId, Auth.UserData data) {
        System.debug('Update User called for: ' + data.email);

        User u = new User(id = userId);
        u.email = data.email;
        u.lastName = data.lastName;
        u.firstName = data.firstName;
        update(u);
    }

    /**
     * Create a Contact
     *
     * @param data - LinkedIn provided context for the User
     **/
    private Id createContact(Auth.UserData data) {
        Contact contact = new Contact();
        contact.LastName = data.lastName;
        contact.FirstName = data.firstName;
        contact.Email = data.email;
        contact.Origin__c = Registration_Handler_Settings__c.getValues('LinkedIn').Origin__c;

        // set Account Id
        if (data.attributemap.get('accountId') != null) {
            contact.accountId = data.attributemap.get('accountId');
        } else {
            List<Account> accounts = [
                    select Id
                    from Account
                    where Name = :Registration_Handler_Settings__c.getValues('LinkedIn').Account_Name__c
            ];
            System.debug('Found account: ' + accounts);

            contact.accountId = accounts[0].Id;
        }
        insert contact;

        System.debug('Contact created for ' + data.email + ' id=' + contact.id);

        return contact.id;
    }

    /**
     * Create and initialize the User but don't save it yet
     *
     * @param data - the provided User context from LinkedIn
     * @param p - the Profile we are going to assign to this user
     *
     * @return User that has been initialized but not Saved
     **/
    private User createUser(Auth.UserData data, Profile p) {
        User u = new User();
        u.username = data.email + Registration_Handler_Settings__c.getValues('LinkedIn').Org_Suffix__c;
        u.email = data.email;
        u.lastName = data.lastName;
        u.firstName = data.firstName;
        String alias = data.firstName + data.lastName;

        //Alias must be 8 characters or less
        if (alias.length() > 8) {
            alias = alias.substring(0, 8);
        }
        u.alias = alias;
        u.languagelocalekey = UserInfo.getLocale();
        u.localesidkey = UserInfo.getLocale();
        u.emailEncodingKey = 'UTF-8';
        u.timeZoneSidKey = [
                SELECT timezonesidkey
                from User
                where profile.name = :Registration_Handler_Settings__c.getValues('LinkedIn').Profile_Name__c
                LIMIT 1
        ].timezonesidkey;
        u.profileId = p.Id;
        return u;
    }
}