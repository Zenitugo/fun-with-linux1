#!/bin/bash


list_of_users="/home/zenitugo/users.txt"
log_file="/var/log/user_management.log"
password_manager="/var/secure/user_passwords.txt"


# Generate random password function for users
generate_password(){
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}


# Create users and groups function
create_users_groups(){
    echo "Create users and assign them to their departments"
    # define the parameters
    users=$1
    groups=$2 


    # check if user exist
    if id -u "$users" &>/dev/null; then
    echo "User $users already exists. Skipping." | tee -a "$log_file"
    return 1
    fi


   # Create groups if they don't exist
    IFS=',' read -ra group_list <<< "$groups"
    for group in "${group_list[@]}"; do
        if ! getent group "$group" &>/dev/null; then
            groupadd "$group"
            echo "Created group $group." | tee -a "$log_file"
        fi
    done

    # Create the user with the specified groups
    useradd -m -G "$groups" "$users"
    echo "Created user $users with groups $groups." | tee -a "$log_file"


    # Set permissions and ownership for the home directory
    chmod 700 "/home/$users"
    chown "$users:$users" "/home/$users"
    echo "Set permissions for /home/$users." | tee -a "$log_file"



    # Generate a random password for the user
    local passwords
    passwords=$(generate_password())
    echo "$users:$passwords" | chpasswd
    echo "Generated password for $users." | tee -a "$log_file"



    # Store the password securely
    echo "$users:$passwords" >> "$password_manager"

    return 0

}



# Main logic
# Check if the file exist
if [ -e "$list_of_users" ]; then
    echo "The file $list_of_users exists."
else
    echo "The file $list_of_users does not exist."
fi


# Check if the file is not empty
if [ -s "$list_of_users" ]; then
    echo "The file $list_of_users is not empty"
else
    echo "The file $list_of_users is empty"
fi

while IFS=';' read -r user groups; do
    create_user_groups "$users" "$groups"
done < "$list_of_users"

echo "User creation process completed." | tee -a "$log_file"

exit 0